/**
 * Encapsulates the code for a particular routine, as well as its state. State
 * is stored as a key/value array that's accessible from within the code.
 */
#ifndef ROUTINE_H
#define ROUTINE_H

#include <map>
#include <string>
#include <stdexcept>
#include <chrono>

#include <angelscript.h>

class CScriptArray;
class CScriptDictionary;

struct HSIPixel {
public:
	double h = 0;
	double s = 0;
	double i = 0;
	
	inline HSIPixel() {}
	inline HSIPixel(double h, double s, double i) : h(h), s(s), i(i) { }
	inline HSIPixel(const HSIPixel& p) {
		this->h = p.h;
		this->s = p.s;
		this->i = p.i;
	}
	inline HSIPixel& operator=(const HSIPixel& other) noexcept {
		// check for self assignment
		if(this != &other) {
			this->h = other.h;
			this->s = other.s;
			this->i = other.i;
		}
		
		return *this;
	}
};

class Routine {
	public:
		// thrown if the script code can't be loaded
		class LoadError : public std::runtime_error {
			public:
				enum ErrorStage {
					kErrorStageNewModule = 1,
					kErrorStageBuildModule,
					kErrorStagePrepareContext
				};

			public:
				LoadError() = delete;
				LoadError(int code, ErrorStage stage) : std::runtime_error("script loading error") {
					this->errCode = code;
					this->stage = stage;

					this->_createWhatString();
				}

				virtual const char* what() const noexcept {
					return this->whatBuf;
				}

			private:
				void _createWhatString();

			private:
				static const int whatBufSz = 4096;
				char whatBuf[whatBufSz];

				int errCode;
				ErrorStage stage;
		};

	public:
		Routine() = delete;
		Routine(std::string code, std::string name);
		Routine(std::string code, std::string name, std::map<std::string, double> &params);
		~Routine();

		void attachBuffer(HSIPixel *buf, size_t elements);
	
		void changeParams(std::map<std::string, double> &newParams);

		void execute(int frame);

		/**
		 * Returns the average time taken to execute the script, in µS.
		 */
		double getAvgExecutionTime() const {
			return this->avgExecutionTime;
		}
		/**
		 * Returns the total number of data points that make up the average
		 * execution time.
		 */
		double getAvgExecutionTimeSamples() const {
			return this->avgExecutionTimeSamples;
		}

	private:
		void _attachDebugger();

		void _cleanUpAngelscriptState();
		void _setUpAngelscriptState();

		void _updateASBufferArray();
		void _copyASBufferArrayData();

		void _setUpAngelscriptGlobals();

		/**
		 * Called immediately before the script executes. This gets the current
		 * time and stores it internally.
		 */
		inline void _scriptExecStart() {
			this->lastStart = std::chrono::high_resolution_clock::now();
		}
		void _scriptExecEnd();

		asIScriptEngine *engine = nullptr;
		asIScriptContext *scriptCtx = nullptr;

		asIScriptFunction *effectStepFxn = nullptr;

	private:
		std::string code;
		std::string name;
	
		std::map<std::string, double> params;

		HSIPixel *buffer;
		int bufferSz = 0;
	
		CScriptArray *asBuffer = nullptr;

		CScriptDictionary *asParams = nullptr;

		int frameCounter = 0;

	private:
		double avgExecutionTime = 0;
		double avgExecutionTimeSamples = 0;

		std::chrono::time_point<std::chrono::high_resolution_clock> lastStart;
};

#endif
