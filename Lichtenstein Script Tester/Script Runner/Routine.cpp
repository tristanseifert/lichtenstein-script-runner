#include "Routine.h"

#include <glog/logging.h>

#include <map>
#include <string>
#include <stdexcept>
#include <chrono>
#include <random>

#include <angelscript.h>
#include <scriptstdstring/scriptstdstring.h>
#include <scriptbuilder/scriptbuilder.h>
#include <scriptarray/scriptarray.h>
#include <scriptdictionary/scriptdictionary.h>
#include <scriptmath/scriptmath.h>

using namespace std;

// turn on to profile how long it takes to copy the pixel buffers
#define PROFILE_BUFCOPY 0

// name of the module that's built
const char *kEffectModuleName = "EffectRoutine";

// declare some C functions
void ASMessageCallback(const asSMessageInfo *msg, void *param);
void ASScriptPrint(string &msg);

void ASHSIPixelConstructor(void *memory);
void ASHSIPixelDestructor(void *memory);
void ASHSIPixelListConstructor(double *list, HSIPixel *self);

int ASRandomIntInRange(int min, int max);

/**
 * Initializes a new routine object with the given database routine (that's how
 * we get our Lua code) and properties to pass to that code.
 */
Routine::Routine(std::string code, std::string name, std::map<std::string, double> &params) {
	this->code = code;
	this->name = name;
	this->params = params;

	this->_setUpAngelscriptState();
}

Routine::Routine(std::string code, std::string name) {
	this->code = code;
	this->name = name;
	this->params = map<string, double>();

	this->_setUpAngelscriptState();
}

/**
 * Destroys the routine. This de-allocates the routine we were passed earlier.
 */
Routine::~Routine() {
	// clean up AngelScript contexts
	this->_cleanUpAngelscriptState();
}

/**
 * Attaches the given buffer to this routine.
 */
void Routine::attachBuffer(HSIPixel *buf, size_t elements) {
	this->buffer = buf;
	this->bufferSz = (int) elements;

	this->_updateASBufferArray();
}

/**
 * Updates the parameters.
 */
void Routine::changeParams(map<string, double> &newParams) {
	this->params = newParams;
	
	// copy them into the script dict
	this->asParams->DeleteAll();
	
	for(auto const& [key, val] : this->params) {
		this->asParams->Set(key, val);
	}
}

#pragma mark - AngelScript Stuff
/**
 * Attaches the debugger to the angelscript context.
 */
void Routine::_attachDebugger() {
//	this->scriptCtx->SetLineCallback(asMETHOD(CDebugger, LineCallback), &dbg, asCALL_THISCALL);
}

/**
 * Cleanly terminates any running scripts, then releases the resources allocated
 * to execute it.
 */
void Routine::_cleanUpAngelscriptState() {
	LOG(INFO) << "Cleaning up AS state";
	
	// release the buffer/param dict we created
	if(this->asBuffer) {
		this->asBuffer->Release();
	}
	
	if(this->asParams) {
		this->asParams->Release();
	}
	
	// abort any currently executing scripts
	if(this->scriptCtx) {
		this->scriptCtx->Abort();
		
		this->scriptCtx->Release();
		this->scriptCtx = nullptr;
	}

	// destroy old angelscript engine
	if(this->engine) {
		this->engine->ShutDownAndRelease();
		this->engine = nullptr;
	}
}

/**
 * Sets up the AngelScript interpreter, loading the code from the routine stored
 * in the database.
 *
 * @note This throws an exception if the code couldn't be parsed/loaded.
 */
void Routine::_setUpAngelscriptState() {
	int err = 0;

	// clean up AngelScript contexts
	this->_cleanUpAngelscriptState();

	// create script engine and register an error handler
	this->engine = asCreateScriptEngine();
	CHECK(this->engine != nullptr) << "Couldn't set up AngelScript context";

	// register message callback
	this->engine->SetMessageCallback(asFUNCTION(ASMessageCallback), 0, asCALL_CDECL);

	// register the std::string class as the string type and our globals
	RegisterStdString(this->engine);
	RegisterScriptArray(this->engine, true);
	RegisterScriptDictionary(this->engine);
	RegisterScriptMath(this->engine);

	this->_setUpAngelscriptGlobals();

	// creating the module
	CScriptBuilder builder;
	err = builder.StartNewModule(engine, kEffectModuleName);

	if(err != 0) {
		LOG(ERROR) << "Couldn't create new AS module: probably out of memory";
		throw LoadError(err, LoadError::kErrorStageNewModule);
	}

	// insert the code from the database
	int scriptSz = (int) this->code.size();
	const char *scriptCode = this->code.c_str();

	// size_t scriptSz = strlen(testScript);
	// const char *scriptCode = testScript;

	err = builder.AddSectionFromMemory(this->name.c_str(), scriptCode,
									   scriptSz, 0);

	if(err != 1) {
		LOG(WARNING) << "Couldn't include user AS code";
		throw LoadError(err, LoadError::kErrorStageBuildModule);
	}

	// build and compile the module
	err = builder.BuildModule();
	if(err != 0) {
		LOG(WARNING) << "Couldn't build AS module: check script syntax";
		throw LoadError(err, LoadError::kErrorStageBuildModule);
	}

	// get the effect function out of the script
	asIScriptModule *mod = this->engine->GetModule(kEffectModuleName);
	this->effectStepFxn = mod->GetFunctionByDecl("void effectStep()");

	if(this->effectStepFxn == nullptr) {
		LOG(WARNING) << "Missing effectStep() function in " << this->name;
		throw LoadError(-1, LoadError::kErrorStagePrepareContext);
	}

	// create a script context to execute on
	this->scriptCtx = this->engine->CreateContext();

#ifdef DEBUG
	this->_attachDebugger();
#endif

	this->scriptCtx->Prepare(this->effectStepFxn);

	if(this->scriptCtx->GetState() == asEXECUTION_PREPARED) {
		VLOG(1) << "Compiled and prepared script context for " << this->name;
	}
}

/**
 * Updates the CScriptArray instance attached to the script under the "buffer"
 * variable. This is called whenever the attached buffer is changed.
 */
void Routine::_updateASBufferArray() {
	// release the previously created array
	if(this->asBuffer) {
		this->asBuffer->Release();
		this->asBuffer = nullptr;
	}

	// create the array
	asITypeInfo *type = this->engine->GetTypeInfoByDecl("array<HSIPixel>");
	this->asBuffer = CScriptArray::Create(type, this->bufferSz);

	VLOG(2) << "Bound new CScriptArray size " << this->bufferSz << " for "
			<< this->name;
}

/**
 * Copies the HSI pixels out of the AngelScript array and into the buffer that
 * was provided for us.
 *
 * This is really kind of hacky, since we _should_ be able to bind the array
 * using the buffer this routine writes into as a backing store, but at least
 * with the CScriptArray class, that's not possible.
 *
 * This _may_ be a performance problem for very, very large arrays, but in
 * reality, copying N number of 24-byte HSI pixels should be stupid fast even
 * on ancient hardware and should add less than a microsecond to the execution
 * time of the script.
 */
void Routine::_copyASBufferArrayData() {
#if PROFILE_BUFCOPY
	auto start = std::chrono::high_resolution_clock::now();
#endif

	for(int i = 0; i < this->bufferSz; i++) {
		HSIPixel *pixel = static_cast<HSIPixel *>(this->asBuffer->At(i));
		this->buffer[i] = *pixel;
	}

#if PROFILE_BUFCOPY
	auto elapsed = std::chrono::high_resolution_clock::now() - start;
	std::chrono::duration<double, std::micro> micros = elapsed;
	double copyTime = micros.count();

	VLOG(3) << "Took " << copyTime << "µS to copy buffers";
#endif
}

/**
 * Sets up globals accessible to the script, such as the buffer size, an object
 * for interacting with the buffer, and the properties passed when the routine
 * was created.
 */
void Routine::_setUpAngelscriptGlobals() {
	int err;

	// register the "debug_print" function
	err = this->engine->RegisterGlobalFunction("void debug_print(const string &in)",
											   asFUNCTION(ASScriptPrint),
											   asCALL_CDECL);
   	CHECK(err >= 0) << "Couldn't register debug_print: " << err;
	
	// register the "rand_int" function
	err = this->engine->RegisterGlobalFunction("int random_range(int min, int max)",
											   asFUNCTION(ASRandomIntInRange),
											   asCALL_CDECL);
	CHECK(err >= 0) << "Couldn't register debug_print: " << err;

	// register the HSIPixel type
	err = this->engine->RegisterObjectType("HSIPixel", sizeof(HSIPixel),
										   asOBJ_VALUE | asGetTypeTraits<HSIPixel>());
	CHECK(err >= 0) << "Couldn't register HSIPixel type: " << err;

	// register a constructor and destructor
	err = this->engine->RegisterObjectBehaviour("HSIPixel", asBEHAVE_CONSTRUCT,
												"void f()",
												asFUNCTION(ASHSIPixelConstructor),
												asCALL_CDECL_OBJLAST);
	CHECK(err >= 0) << "Couldn't register HSIPixel constructor: " << err;
	err = this->engine->RegisterObjectBehaviour("HSIPixel", asBEHAVE_LIST_CONSTRUCT,
												"void f(const int &in) {double, double, double}",
												asFUNCTION(ASHSIPixelListConstructor),
												asCALL_CDECL_OBJLAST);
	CHECK(err >= 0) << "Couldn't register HSIPixel list constructor: " << err;
	
	err = this->engine->RegisterObjectBehaviour("HSIPixel", asBEHAVE_DESTRUCT,
												"void f()",
												asFUNCTION(ASHSIPixelDestructor),
												asCALL_CDECL_OBJLAST);
	CHECK(err >= 0) << "Couldn't register HSIPixel destructor: " << err;
	
	// register assignment operator
	err = this->engine->RegisterObjectMethod("HSIPixel",
											 "HSIPixel &opAssign(const HSIPixel &in)",
											 asMETHODPR(HSIPixel,operator =, (const HSIPixel &), HSIPixel&),
											 asCALL_THISCALL);
	CHECK(err >= 0) << "Couldn't register HSIPixel assignment operator: " << err;


	// register fields in the HSIPixel type
	err = this->engine->RegisterObjectProperty("HSIPixel", "double h",
											   asOFFSET(HSIPixel, h));
   	CHECK(err >= 0) << "Couldn't register HSIPixel.h: " << err;

	err = this->engine->RegisterObjectProperty("HSIPixel", "double s",
											   asOFFSET(HSIPixel, s));
   	CHECK(err >= 0) << "Couldn't register HSIPixel.s: " << err;

	err = this->engine->RegisterObjectProperty("HSIPixel", "double i",
											   asOFFSET(HSIPixel, i));
   	CHECK(err >= 0) << "Couldn't register HSIPixel.i: " << err;

	// set up buffer size
	err = this->engine->RegisterGlobalProperty("int bufferSz", &this->bufferSz);
	CHECK(err >= 0) << "Couldn't register buffer size global: " << err;

	// set up the data array
	err = this->engine->RegisterGlobalProperty("array<HSIPixel> @buffer", &this->asBuffer);
	CHECK(err >= 0) << "Couldn't register buffer pointer global: " << err;

	// register frame counter
	err = this->engine->RegisterGlobalProperty("int frameCounter", &this->frameCounter);
	CHECK(err >= 0) << "Couldn't register frame counter global: " << err;

	// set up a dictionary to hold properties
	this->asParams = CScriptDictionary::Create(this->engine);

	err = this->engine->RegisterGlobalProperty("dictionary @properties", &this->asParams);
	CHECK(err >= 0) << "Couldn't register properties global: " << err;

	// copy all the properties from the params map
	for(auto const& [key, val] : this->params) {
		this->asParams->Set(key, val);
	}
}

/**
 * Executes the script's step function. "frame" is the frame counter passed to
 * the script via the "frameCounter" global.
 */
void Routine::execute(int frame) {
	int err;

	// start of execution
	this->_scriptExecStart();

	// prepare the context again… this is required before each invocation
	this->scriptCtx->Prepare(this->effectStepFxn);

	// copy the frame counter
	this->frameCounter = frame;

	// execute and check return value
	err = this->scriptCtx->Execute();

	if(err != asEXECUTION_FINISHED) {
		if(err == asEXECUTION_EXCEPTION) {
			// get line number
			int line, col;
			const char *section;
			line = this->scriptCtx->GetExceptionLineNumber(&col, &section);

			LOG(ERROR) << "Exception while executing " << this->name
					   << ": " << this->scriptCtx->GetExceptionString() << " at "
					   << line << ':' << col << " in section " << section;
		}
	}

	// end of execution time
	this->_scriptExecEnd();

	// copy the buffers
	this->_copyASBufferArrayData();
}

/**
 * Constructor for the HSIPixel type.
 */
void ASHSIPixelConstructor(void *memory) {
  new(memory) HSIPixel();
}

/**
 * Destructor for the HSIPixel type.
 */
void ASHSIPixelDestructor(void *memory) {
  ((HSIPixel *) memory)->~HSIPixel();
}

/**
 * List constructor for the HSIPixel type.
 */
void ASHSIPixelListConstructor(double *list, HSIPixel *self) {
	new(self) HSIPixel(list[0], list[1], list[2]);
}

/**
 * Returns a random number in the given range.
 */
int ASRandomIntInRange(int min, int max) {
	random_device rd; // obtain a random number from hardware
	mt19937 eng(rd()); // seed the generator
	uniform_int_distribution<> distr(min, max); // define the range
	
	return distr(eng);
}

/**
 * Logging of messages from the script itself; these are logged to the global
 * logger as verbose messages.
 */
void ASScriptPrint(string &msg) {
	int line, col;
	const char *section;

	asIScriptContext *ctx = asGetActiveContext();
	line = ctx->GetLineNumber(0, &col, &section);

	LOG(INFO) << "[" << section << ' ' << line << ':' << col << "] " << msg;
}

/**
 * message handler for AngelScript - any messages given from the engine are just
 * printed to the log using the standard logging functions.
 */
void ASMessageCallback(const asSMessageInfo *msg, void *param) {
	// format the message
	static const int msgBufSz = 4096;
	char msgBuf[msgBufSz];

	snprintf(msgBuf, msgBufSz, "AngelScript Message [section '%s' (%d:%d)] %s",
			 msg->section, msg->row, msg->col, msg->message);

	// log it
	if(msg->type == asMSGTYPE_ERROR) {
		LOG(ERROR) << msgBuf;
	} else if(msg->type == asMSGTYPE_WARNING) {
		LOG(WARNING) << msgBuf;
	} else if(msg->type == asMSGTYPE_INFORMATION) {
		LOG(INFO) << msgBuf;
	}
}

#pragma mark - Performance Counters
/**
 * Called immediately after the script has executed. Calculates the difference
 * between the start and end times, converts it to microseconds, and adds it to
 * the moving average that's internally tracked.
 */
void Routine::_scriptExecEnd() {
	// calculate the difference and get microseconds
	auto elapsed = std::chrono::high_resolution_clock::now() - this->lastStart;
	std::chrono::duration<double, std::micro> micros = elapsed;

	double execTime = micros.count();

	// add it to the moving average
	double n = this->avgExecutionTimeSamples;
	double oldAvg = this->avgExecutionTime;

	double newAvg = ((oldAvg * n) + execTime) / (n + 1);

	this->avgExecutionTime = newAvg;
	this->avgExecutionTimeSamples++;
}

#pragma mark - Exceptions
/**
 * Creates a pretty error string (the "what" string) for this exception.
 */
void Routine::LoadError::_createWhatString() {
	snprintf(this->whatBuf, this->whatBufSz,
			 "AngelScript error: stage %u, error %i", this->stage, this->errCode);
}
