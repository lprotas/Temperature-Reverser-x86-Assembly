TITLE Temperature Reverser      (Proj6_protasl.asm)

; Description:	This program reads a line of temperature readings from a file, 
;				it then converts the string-formatted integers into numeric values, 
;				and prints them in reverse order.
;				The program uses custom macros for user I/O, string parsing, 
;				and strict parameter passing via the runtime stack.

INCLUDE Irvine32.inc

; ---------------------------------------------------------------------------------
; Name: mGetString
;
; reads a string from standard input into a buffer.
;
; preconditions:
;	- do not use eax, ecx, edx as arguments.
;	- buffer must be large enough to hold the input.
;
; receives:
;	memoryoffset = address of the destination buffer
;	countvalue   = maximum number of characters to read
;	bytesreadoffset = address to store the number of bytes actually read
;
; returns:
;	[bytesreadoffset] = number of bytes read (including null terminator)
;	[memoryoffset]    = buffer containing the input string (null-terminated)
; ---------------------------------------------------------------------------------
mGetString MACRO memoryOffset, countValue, bytesReadOffset
	; save registers and set up for readstring
	push    edx
	push    ecx
	push    eax
	mov     edx, memoryOffset
	mov     ecx, countValue
	call    readstring
	mov     [bytesReadOffset], eax
	pop     eax
	pop     ecx
	pop     edx
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayString
;
; displays a null-terminated string to standard output.
;
; preconditions:
;	- do not use edx as an argument.
;	- the string must be null-terminated and accessible at the given address.
;
; receives:
;	stringoffset = address of the null-terminated string to display
;
; returns:
;	none
; ---------------------------------------------------------------------------------
mDisplayString MACRO stringOffset
	; save edx and call writestring
	push    edx
	mov     edx, stringOffset
	call    writestring
	pop     edx
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayChar
;
; displays a single character to standard output.
;
; preconditions:
;	- do not use eax as an argument.
;	- the character value must fit in a byte (ascii).
;
; receives:
;	charval = the character (or ascii code) to display
;
; returns:
;	none
; ---------------------------------------------------------------------------------
mDisplayChar MACRO charVal
	; save eax and call writechar
	push	eax
	mov		al,	charVal
	call	writechar
	pop		eax
ENDM

; ---------------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------------
DELIMITER               EQU     ','
TEMPS_PER_DAY           =       24
INVALID_HANDLE_VALUE    =       -1
BUFFER_SIZE             =       512
ARRAYSIZE               =       TEMPS_PER_DAY

; ---------------------------------------------------------------------------------
; Data Section 
; ---------------------------------------------------------------------------------
.data

; program information and description strings
programTitle            BYTE    "Welcome to Awesome-Thermo-R-4000: Rewind. Reorder. Repair.", 0
programPurpose          BYTE    "Intern broke it. We fix it. Hero mode: ON.", 0
programDesc1            BYTE    "This program reads temperature measurements from a file.", 0
programDesc2            BYTE    "Please ensure the file is in plain ASCII text format.", 0
programDesc3            BYTE    "Once loaded, it will correctly re-arrange the sequence of temperatures.", 0
programDesc4            BYTE    "Finally, it will display the corrected order for you!", 0
extraCredit1            BYTE    "*EC: This program implements a WriteVal procedure to convert integers to strings and display them, rather than using WriteDec/WriteInt.", 0

; user prompt strings
programPrompt           BYTE    "Please enter the name of the file to be read: ", 0

; output and error message strings
results                 BYTE    13, 10, "Your crazy intern entered the following numbers: ", 13, 10, 0
fileError               BYTE    "ERROR: Could not open file or read data.", 13, 10, 0
comma                   BYTE    ",",0
space                   BYTE    " ",0
correctedOrderMsg       BYTE    13, 10, "Here's the corrected temperature order!", 13, 10, 0

; main data buffers and arrays
array                   SDWORD  ARRAYSIZE DUP(?)

fileNameBuffer          BYTE    80 DUP(0)
fileBuffer              BYTE    BUFFER_SIZE DUP(0)
outBuffer               BYTE    BUFFER_SIZE DUP(?) ; reserve space for the output buffer

; file and runtime state variables
bytesRead               DWORD   ?
fileHandle              DWORD   ?
actualTempsParsed       DWORD   0

; ---------------------------------------------------------------------------------
; Code Section
; ---------------------------------------------------------------------------------
.code

; ---------------------------------------------------------------------------------
; Main procedure
; ---------------------------------------------------------------------------------
main PROC

	; display program introduction and instructions
	mDisplayString OFFSET programTitle
	call	crlf
	call	crlf
	mDisplayString OFFSET programPurpose
	call	crlf
	call	crlf
	mDisplayString OFFSET programDesc1
	call	crlf
	mDisplayString OFFSET programDesc2
	call	crlf
	mDisplayString OFFSET programDesc3
	call	crlf
	mDisplayString OFFSET programDesc4
	call	crlf
	call	crlf
	mDisplayString OFFSET extraCredit1
	call	crlf
	call	crlf

	; prompt for filename and get input from user
	mDisplayString OFFSET programPrompt
	mGetString OFFSET fileNameBuffer, SIZEOF fileNameBuffer - 1, bytesRead

	; remove trailing newline/carriage return from filename
	mov		edx, OFFSET fileNameBuffer
	call	RemoveTrailingNewLines

	; open the input file for reading
	mov		edx, OFFSET fileNameBuffer
	call	openinputfile
	mov		fileHandle, eax
	cmp		eax, INVALID_HANDLE_VALUE
	je		fileOpenError

	; zero out fileBuffer before reading file contents
	mov		ecx, BUFFER_SIZE
	mov		edi, OFFSET fileBuffer
	mov		al, 0
	rep		stosb

	; read file contents into fileBuffer
	mov		eax, fileHandle
	mov		edx, OFFSET fileBuffer
	mov		ecx, BUFFER_SIZE - 1
	call	readfromfile

	mov		bytesRead, eax
	mov		byte ptr [fileBuffer + eax], 0 ; null-terminate the buffer

	; close the input file
	mov		edx, fileHandle
	call	closefile

	; parse the buffer into an array of integers
	push	OFFSET array
	push	OFFSET fileBuffer
	call	ParseTempsFromString
	mov		actualTempsParsed, eax

	; display the parsed array in original order
	push    OFFSET space
	push    OFFSET comma
	push    OFFSET outBuffer
	push    OFFSET results
	push    OFFSET array
	call    WriteArray

	; display the corrected order message and reversed array
	call	crlf
	mDisplayString OFFSET correctedOrderMsg
	push	OFFSET array
	call	WriteTempsreverse

	; exit the program successfully
	invoke	exitprocess, 0

fileOpenError:
	; display file error message and exit with error code
	mDisplayString OFFSET fileError
	invoke	exitprocess, 1
main ENDP

; ---------------------------------------------------------------------------------
; Name: RemoveTrailingNewlines
;
; removes trailing carriage return (cr, ascii 13) and line feed (lf, ascii 10)
; characters from the end of a null-terminated string. this is useful for
; cleaning up input strings read from files or the console.
;
; preconditions:
;	- edx must contain the offset (address) of a null-terminated string.
;	- the string must be writable in memory.
;
; postconditions:
;	- edx is preserved.
;	- eax and edi are modified but restored before return.
;
; receives:
;	- edx: address of the null-terminated string to process.
;
; returns:
;	- the string at [edx] will have any trailing cr (13) and/or lf (10) bytes
;	  removed and replaced with a null terminator (0).
; ---------------------------------------------------------------------------------
RemoveTrailingNewlines PROC
	
	; save registers and set edi to the start of the string
	push	eax
	push	edi

	mov		edi, edx

_find_null_terminator:
	; find the null terminator at the end of the string
	cmp		byte ptr [edi], 0
	je		_found_null_terminator
	inc		edi
	jmp		_find_null_terminator

_found_null_terminator:
	; step back to the last character before null
	dec		edi

	mov		al, [edi]
	cmp		al, 0ah
	jne		_check_cr_after_lf
	mov		byte ptr [edi], 0	; remove line feed if present
	dec		edi

_check_cr_after_lf:
	; check for carriage return and remove if present
	mov		al, [edi]
	cmp		al, 0dh
	jne		_finish_remove
	mov		byte ptr [edi], 0	; remove carriage return if present	

_finish_remove:
	; restore registers and return
	pop		edi
	pop		eax
	ret
RemoveTrailingNewlines ENDP

; ---------------------------------------------------------------------------------
; Name: ParseTempsFromString
;
; parses a null-terminated string containing comma-separated signed integers,
; converts them to sdword values, and stores them in an array. skips whitespace
; and handles both positive and negative numbers. stops parsing at the end of the
; string or when the maximum number of values (temps_per_day) is reached.
;
; preconditions:
;	- the input string must be null-terminated and accessible for reading.
;	- the output array must be large enough to hold up to temps_per_day sdwords.
;	- the procedure is called using stdcall convention with two arguments pushed:
;	  (push inputstringptr, push outputarrayptr, call parsetempsfromstring)
;
; postconditions:
;	- eax contains the number of integers successfully parsed and stored.
;	- esi, edi, ebx, ecx, and edx are modified but restored before return.
;
; receives:
;	- [ebp+8]: address of the input null-terminated string (source buffer).
;	- [ebp+12]: address of the output sdword array (destination buffer).
;
; returns:
;	- eax: number of integers parsed and stored in the output array.
;	- the output array at [ebp+12] is filled with the parsed sdword values.
; ---------------------------------------------------------------------------------
ParseTempsFromString PROC
	; save registers and set up pointers
	push	ebp
	mov		ebp, esp
	push	esi 
	push	edi 
	push	ebx 
	push	ecx 
	push	edx 

	mov		esi, [ebp+8]	; esi points to input string
	mov		edi, [ebp+12]	; edi points to output array
	xor		ecx, ecx		; ecx = count of parsed numbers

_nextTempLoop:
	; check if we've parsed the maximum number of temperatures
	cmp		ecx, TEMPS_PER_DAY
	jge		_doneParsing

_skipWhitespace:
	; skip whitespace and line breaks
	mov		al, [esi]
	cmp		al, 0
	je		_doneParsing
	cmp		al, ' '
	je		_advanceESIAndSkip
	cmp		al, 0dh
	je		_advanceESIAndSkip
	cmp		al, 0ah
	je		_advanceESIAndSkip
	jmp		_startParsingNumber

_advanceESIAndSkip:
	; advance pointer past whitespace
	inc		esi
	jmp		_skipWhitespace

_startParsingNumber:
	; initialize number accumulator and sign flag
	xor		edx, edx	; edx will accumulate the integer value
	xor		bl, bl		; bl = 1 if negative, 0 if positive

	mov		al, [esi]
	cmp		al, '-'
	jne		_checkPlusSign
	mov		bl, 1		; set sign flag for negative
	inc		esi
	jmp		_parseDigitsLoop

_checkPlusSign:
	; handle optional plus sign
	cmp		al, '+'
	jne		_beginDigitCheck
	inc		esi

_beginDigitCheck:
_parseDigitsLoop:
	; parse digits and build the integer value
	mov		al, [esi]
	cmp		al, DELIMITER
	je		_storeValue
	cmp		al, 0
	je		_storeValue
	cmp		al, ' '
	je		_storeValue
	cmp		al, 0dh
	je		_storeValue
	cmp		al, 0ah
	je		_storeValue

	cmp		al, '0'
	jb		_storeValue
	cmp		al, '9'
	ja		_storeValue

	sub		al, '0'			; convert ascii digit to integer
	movzx	eax, al
	imul	edx, edx, 10	; multiply accumulator by 10 (shift left in decimal)
	add		edx, eax		; add new digit to accumulator

	inc		esi
	jmp		_parseDigitsLoop

_storeValue:
	; store the parsed integer in the array, apply sign if needed
	test	bl, bl
	jz		_storePositive
	neg		edx				; make value negative if sign flag set

_storePositive:
	mov		eax, edx
	stosd					; store value in output array, advance edi

	inc		ecx				; increment count of parsed numbers

_skipTrailingChars:
	; skip delimiters and whitespace after a number
	mov		al, [esi]
	cmp		al, 0
	je		_doneParsing
	cmp		al, DELIMITER
	je		_advanceESIAndSkipTrailing
	cmp		al, ' '
	je		_advanceESIAndSkipTrailing
	cmp		al, 0dh
	je		_advanceESIAndSkipTrailing
	cmp		al, 0ah
	je		_advanceESIAndSkipTrailing
	jmp		_nextTempLoop

_advanceESIAndSkipTrailing:
	inc		esi
	jmp		_skipTrailingChars

_doneParsing:
	; return the count of parsed temperatures in eax
	mov		eax, ecx

	pop		edx
	pop		ecx
	pop		ebx
	pop		edi
	pop		esi
	pop		ebp
	ret		8
ParseTempsFromString ENDP

; ---------------------------------------------------------------------------------
; Name: WriteTempsReverse
;
; displays the contents of an sdword array in reverse order, printing each value
; separated by a comma and a space. uses the writeval procedure to convert each
; integer to a string for output. a newline is printed after the last value.
;
; preconditions:
;	- the array must contain temps_per_day sdword values.
;	- the procedure is called using stdcall convention with one argument pushed:
;	  (push arrayptr, call writetempsreverse)
;	- the outbuffer global variable must be available for writeval.
;
; postconditions:
;	- all registers are preserved (uses pushad/popad).
;
; receives:
;	- [ebp+8]: address of the sdword array to display in reverse order.
;
; returns:
;	- none. output is written to the console.
; ---------------------------------------------------------------------------------
WriteTempsReverse PROC
	; save all registers and set up pointers
	push	ebp
	mov		ebp, esp
	pushad

	mov		esi, [ebp+8]
	mov		ecx, TEMPS_PER_DAY
	
	cmp		ecx, 0
	je		_donePrintingReverse
	dec		ecx

	lea		esi, [esi + ecx*4]	; point esi to the last element in the array

_printReverseLoop:
	; print each value in reverse order
	cmp		ecx, -1
	je		_donePrintingReverse

	mov		eax, [esi]
	push	OFFSET outBuffer
	push	eax
	call	writeval			; convert and print value

	cmp		ecx, 0
	je		_noDelim

	mDisplayChar DELIMITER
	mDisplayChar ' '

_noDelim:
	sub		esi, 4				; move to previous element (arrays of dwords)
	dec		ecx
	jns		_printReverseLoop	

_donePrintingReverse:
	; print a newline after the last value
	call	crlf

	popad
	pop		ebp
	ret		4
WriteTempsReverse ENDP

; ---------------------------------------------------------------------------------
; Name: WriteVal
;
; converts a signed integer value to its ascii string representation and displays
; it using mdisplaystring. handles negative values and zero. the result is written
; to a provided output buffer, which is cleared before use.
;
; preconditions:
;	- the output buffer at [ebp+12] must be large enough to hold the ascii string
;	  representation of the integer (including sign and null terminator).
;	- the procedure is called using stdcall convention with two arguments pushed:
;	  (push value, push bufferptr, call writeval)
;	- mdisplaystring macro must be available.
;
; postconditions:
;	- eax, ebx, ecx, edx, edi, and esi are modified but restored before return.
;
; receives:
;	- [ebp+8]:  the signed integer value to convert and display.
;	- [ebp+12]: address of the output buffer (byte array).
;
; returns:
;	- the output buffer at [ebp+12] contains the null-terminated ascii string
;	  representation of the integer.
;	- the value is displayed to the console.
; ---------------------------------------------------------------------------------
WriteVal PROC
	; save registers and clear the output buffer
	push    ebp
	mov     ebp, esp
	push    eax
	push    ebx 
	push    ecx 
	push    edx 
	push    edi
	push    esi 

	; clear the output buffer
	mov     ecx, BUFFER_SIZE
	mov     edi, [ebp+12]
_clearLoop:
	cld
	mov		al,0
	stosb							; zero out the output buffer
	dec     ecx
	jnz     _clearLoop

	; prepare for integer to ascii conversion
	mov     eax, [ebp+8]
	xor     edx, edx
	mov     esi, 0

	mov     edi, [ebp+12]
	add     edi, BUFFER_SIZE - 1	; point edi to end of buffer

	cmp     eax, 0
	je      _zeroVal

	cmp     eax, 0
	jg      _writeIntVal
	mov     esi, 1
	neg     eax						; make value positive for conversion

_writeIntVal:
	; convert integer to ascii digits (in reverse order)
	mov     ecx, 10
	cdq
	idiv    ecx
	add     dl, '0'
	dec     edi
	mov     byte ptr [edi], dl		; store ascii digit in buffer
	inc     ebx
	test    eax, eax
	jnz     _writeIntVal

	cmp     esi, 1
	je      _addSignVal
	jmp     _doneVal

_zeroVal:
	; handle the special case of zero
	mov     edi, [ebp+12]
	mov     byte ptr [edi], '0'
	mov     byte ptr [edi+1], 0
	jmp     _doneVal

_addsignVal:
	; add minus sign for negative numbers
	dec     edi
	mov     byte ptr [edi], '-'
	inc     ebx
_doneVal:
	; display the resulting string
	mov     edx, edi
	mDisplayString edx

	pop     esi
	pop     edi
	pop     edx
	pop     ecx
	pop     ebx
	pop     eax
	pop     ebp
	ret     8
WriteVal ENDP

; ---------------------------------------------------------------------------------
; Name: WriteArray
;
; displays the contents of an sdword array in order, separated by commas and spaces.
; prints a results message before the array. each value is converted to a string
; using writeval and output to the console. commas and spaces are printed between
; values, but not after the last value.
;
; preconditions:
;	- the array must contain arraysize (temps_per_day) sdword values.
;	- the procedure is called using stdcall convention with five arguments pushed:
;	  (push arrayptr, push resultsstr, push outbuffer, push commastr, push spacestr, call writearray)
;	- the outbuffer global variable must be available for writeval.
;	- the results, comma, and space strings must be null-terminated and accessible.
;
; postconditions:
;	- ebx, edx, edi, and ecx are modified but restored before return.
;
; receives:
;	- [ebp+8]:  address of the sdword array to display.
;	- [ebp+12]: address of the results message string to display before the array.
;	- [ebp+16]: address of the output buffer for writeval.
;	- [ebp+20]: address of the comma string (separator).
;	- [ebp+24]: address of the space string (separator).
;
; returns:
;	- none. output is written to the console.
; ---------------------------------------------------------------------------------
WriteArray PROC
	; save registers and set up pointers
	push    ebp
	mov     ebp, esp
	push    ebx
	push    edx
	push    edi
	push    ecx

	mov     edi, [ebp+8]
	mov     ecx, ARRAYSIZE

	mov     edx, [ebp+12]
	mDisplayString edx

	xor     edx, edx

_printLoop:
	; print each value in the array
	cmp     edx, ecx
	jge     _endPrintLoop

	mov     ebx, [edi + edx * 4]	; fetch the next array element

	push    [ebp+16]
	push    ebx
	call    writeval				; print value

	inc     edx

	cmp     edx, ecx
	jge     _endPrintLoop

	mDisplayString  [ebp+20]
	mDisplayString  [ebp+24]

	jmp     _printLoop        

_endPrintLoop:
	; restore registers and return
	pop     ecx
	pop     edi
	pop     edx
	pop     ebx
	pop     ebp
	ret     20
WriteArray ENDP

END main
