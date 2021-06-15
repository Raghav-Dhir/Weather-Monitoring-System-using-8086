#LOAD_SEGMENT=0500H#
#LOAD_OFFSET=0000H#

#CS=0500H#
#IP=0000H#

#DS=0500H#
#ES=0500H#

#SS=0000H#
#SP=FFFEH#

; set general registers (optional)
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#




MOV AX, OFFSET ISR0			;Initialisation of Interrupt Vector Table 
MOV [00200H], AX 			
MOV AX, SEG ISR0
MOV [00202H], AX

MOV AX, OFFSET ISR1
MOV [00204H], AX
MOV AX, SEG ISR1
MOV [00206H], AX

MOV AX, OFFSET ISR2
MOV [00208H], AX
MOV AX, SEG ISR2
MOV [0020AH], AX

MOV AX, OFFSET ISR3
MOV [0020CH], AX
MOV AX, SEG ISR3
MOV [0020EH], AX


JMP START
DB 512 DUP(0)

;-------------------------DATA-SEGMENT-----------------------;
CSTATEA DB 00H
CSTATEB DB 00H

T_DISP DB 'TEM(C):'    		;Temperature 
LCDLN2 DB 16 DUP('-')
LCDLN3 DB 16 DUP('.')
LCDLN4 DB 16 DUP('*')
T_CNT DB 7D


T_FLAG	DW 0
VALS 		DB 12 DUP(0)
CTR 		DW 0
READYFORHOUR DB 1 DUP(0)

THP DB 1 DUP(0)


H_DISP DB 'HUM(%):' 		;Humidity 
LCDLN22 DB 16 DUP('-')
LCDLN33 DB 16 DUP('.')
LCDLN44 DB 16 DUP('*')
H_CNT DB 7D

H_FLAG	DW 0
VALS11 		DB 12 DUP(0)
CTR11 		DW 0


P_DISP DB 'PRES(BA):' 		;Pressure 
LCDLN222 DB 16 DUP('-')
LCDLN333 DB 16 DUP('.')
LCDLN444 DB 16 DUP('*')
P_CNT DB 9D

P_FLAG	DW 0
VALS111		DB 12 DUP(0)
CTR111		DW 0

NUMSTR DB 16 DUP(0)

Q DB 0
R DB 0

DIVBY DW 12D
UPDATENOW DB 00H


;------------------------START-INITS-----------------------; 

START: CLI

A8259 EQU 4000H
A8255 EQU 4010H
B8255 EQU 4020H
A8253 EQU 4030H
B8253 EQU 4040H


8259_INIT:

;ICW1
MOV AL, 00010011B   ;ICW4 NEEDED (SINGLE 8259)
MOV DX, A8259+00H   ; DX HAS 1ST ADDRESS OF 8259
OUT DX, AL

;ICW2
MOV AL, 10000000B   ; DX HAS 2ND ADDRESS OF 8259
MOV DX, A8259+02H   ; 80H IS GENERATEDFOR IR0 IE BUT-INT
OUT DX,AL

;ICW4
MOV AL, 00000011B       ; REST FOLLOW 80H - 87H
OUT DX,AL
 
;OCW1
MOV AL, 11111110B   ; NON BUFFERED MODE WITH AEOI ENABLED
OUT DX, AL  


8255_INIT:			
MOV AL, 10000010B       ;Port A -O/P. Port B -I/P
MOV DX, A8255+06H
OUT DX, AL

;Initalise 8255 B for controlling ADC 
MOV AL, 10000010B
MOV DX, B8255+06H
OUT DX, AL  

8253_INIT:              ; COUNTER0 - SQ. WAVE - BINARY I/P(2MHZ-I/P)
;1MHZ
MOV AL, 00010110B
MOV DX, A8253+06H
OUT DX, AL
MOV AL, 02H
MOV DX, A8253+00H       ; TO INPDE BY 2 - TO GIVE 1MHZ
OUT DX, AL


;16HZ
MOV AL, 01110110B       ;COUNTER1 - SQ. WAVE - BINARY I/P
MOV DX, A8253+06H
OUT DX, AL
MOV AL, 24H              ; COUNT = 62500 = 0F424H
MOV DX, A8253+02H
OUT DX, AL
MOV AL, 0F4H
OUT DX, AL

;5MIN
MOV AL, 10110100B       ;CNTR3 - USING MODE 2 - EVERY 5 MIN(LOW)
MOV DX, A8253+06H       ;MUST BE INVERTED AND GIVEN AS INTERRUPT
OUT DX, AL
MOV AL, 0C0H
MOV DX, A8253+04H
OUT DX, AL
MOV AL, 12H
OUT DX, AL

;1HR
MOV AL, 00110100B       ;COUNTER 0 - 16HZ TO 1HR PULSE (OBSOLETE)
MOV DX, B8253+06H
OUT DX, AL
MOV AL, 00H
MOV DX, B8253+00H
OUT DX, AL
MOV AL, 0E1H
OUT DX, AL  


LCD_INIT:
LCDEN EQU 80H
LCDRW EQU 40H
LCDRS EQU 20H

ACLRB LCDRW
LCD_OUT 38H
LCD_OUT 0EH
LCD_OUT 06H

LCD_CLEAR

;------------------------START-CODE-------------------------;

; PERFORM INITIAL DISPLAY ...

;TURN ON ADC - TEMPERATURE
MOV THP,00H
INT 81H     
        
;WAIT FOR EOC

EOCINT1:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT1

EOCINT2:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT2

MOV THP,00H
INT 83H			;Store Values for Temperature

MOV THP,01H
INT 81H     	;Repeat for HUMIDITY


EOCINT3:   		;Loop to wait for end of Conversion 
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT3

EOCINT4:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT4


MOV THP,01H
INT 83H

MOV THP,11H
INT 81H     

;WAIT FOR EOC
EOCINT5:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT5

EOCINT6:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT6


MOV THP,11H
INT 83H


MOV THP,00H
INT 82H
MOV THP,01H
INT 82H
MOV THP,11H
INT 82H

; --------END OF INITIAL DISPLAY ---------------

;POLL PORTB OF A8255 FOREVER
XINF:
;CHECK IF BUTTON IS PRESSED USING A FLAG STORED IN MEMORY
MOV AL, UPDATENOW
CMP AL, 01H
JNZ CONT
MOV UPDATENOW, 00H

MOV THP,00H         ;FOR TEMPERATURE
INT 81H ;TURN ON ADC

;WAIT FOR EOC
EOCINT7:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT7

EOCINT8:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT8


MOV THP,00H
INT 83H

MOV THP,01H
INT 81H     ; DO SAME FOR HUMI

;WAIT FOR EOC
EOCINT9:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT9

EOCINT10:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT10


MOV THP,01H
INT 83H


MOV THP,11H ; FOR PRESSURE
INT 81H



;WAIT FOR EOC
EOCINT11:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT11

EOCINT12:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT12

MOV THP,11H
INT 83H


MOV THP,00H
INT 82H
MOV THP,01H
INT 82H
MOV THP,11H
INT 82H



;REGULAR POLLING
CONT:
MOV DX, A8255+02H
IN AL, DX

MOV BL, AL
AND BL, 01H
JZ BUTINT

MOV BL, AL
AND BL, 02H
JZ FIVEMIN

MOV BL, AL
AND BL, 04H
JZ ONEHR

MOV BL, AL
AND BL, 08H
JZ EOCINT
JMP XINF

;LOW LOGIC DETECTED. WAIT FOR WHOLE PULSE
BUTINT:
IN AL, DX
AND AL, 01H
JZ BUTINT

INT 80H
JMP XINF

FIVEMIN:
IN AL, DX
AND AL, 02H
JZ FIVEMIN

MOV THP,00H
INT 81H

EOCINT13:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT13

EOCINT14:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT14

MOV THP,00H
INT 83H


MOV THP,01H
INT 81H


;WAIT FOR EOC
EOCINT15:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT15


EOCINT16:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT16

MOV THP,01H
INT 83H


MOV THP,11H
INT 81H


;WAIT FOR EOC
EOCINT17:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JNZ EOCINT17


EOCINT18:
MOV DX, A8255+02H
IN AL, DX
MOV BL, AL
AND BL, 08H
JZ EOCINT18

MOV THP,11H
INT 83H


;CHANGE VALUE OF NO. OF 5 MIN INTERVALS TAKEN DURING SIMULATION
 
INC READYFORHOUR

CMP READYFORHOUR,02H
JNZ DONOTCALLONEHOUR

MOV THP,00H
INT 82H ; CALL THE 1 HOUR INTERRUPT
MOV THP,01H
INT 82H
MOV THP,11H
INT 82H

MOV READYFORHOUR,00H ; RESET THE 12, 5-MIN INTERVAL COUNT


DONOTCALLONEHOUR: JMP XINF


; OBSOLETE. IS NOT USE AS INTRPT IS CALLED DIRECTLY

ONEHR:
IN AL, DX
AND AL, 04H
JZ ONEHR

INT 82H
JMP XINF

EOCINT:
IN AL, DX
AND AL, 08H
JZ EOCINT

MOV THP,00H
INT 83H
MOV THP,01H
INT 83H
MOV THP,11H
INT 83H


JMP XINF

JMP QUIT



;------------------------START-MACROS-----------------------;
PUSHALL MACRO
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
ENDM

POPALL MACRO
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
ENDM

                            ;Routines for Setting/Resetting Pins since this was more convenient than BSR 
ASETB    MACRO MBIT			;SET ONLY THE GIVEN PINS 
    PUSHALL
    MOV AL, MBIT
    MOV BL, CSTATEA
    OR  AL, BL
    MOV DX, A8255+04H
    OUT DX, AL
    MOV BL, AL
    MOV CSTATEA, BL
    POPALL            
ENDM


ACLRB    MACRO MBIT ;CLEAR ONLY THE GIVEN PINS 
    PUSHALL
    MOV AL, MBIT
    XOR AL, 0FFH
    MOV BL, CSTATEA
    AND AL, BL
    MOV DX, A8255+04H
    OUT DX, AL
    MOV BL, AL
    MOV CSTATEA, BL
    POPALL             
ENDM

ADCST EQU 01H
ADCOE EQU 02H
ADCA EQU 04H
ADCB EQU 08H
ADCC EQU 10H
ADCALE EQU 20H

BSETB    MACRO MBIT
    PUSHALL
    MOV AL, MBIT
    MOV BL, CSTATEB
    OR  AL, BL
    MOV DX, B8255+04H
    OUT DX, AL
    MOV BL, AL
    MOV CSTATEB, BL
    POPALL            
ENDM


BCLRB    MACRO MBIT
    PUSHALL
    MOV AL, MBIT
    XOR AL, 0FFH
    MOV BL, CSTATEB
    AND AL, BL
    MOV DX, B8255+04H
    OUT DX, AL
    MOV BL, AL
    MOV CSTATEB, BL
    POPALL             
ENDM

LCD_OUT    MACRO DAT
    ACLRB LCDRS					;CLEARS LCD RESET PIN 
    PUSHALL						;PUSHES ALL REGISTERS TO STACK 
    MOV AL, DAT					;COPIES DATA TO BE SENT TO LCD 
    MOV DX, A8255+00H			;SETS ADDRESS OF DATA TO BE SENT 
    OUT DX, AL					;SENDS DATA TO LCD 
    ASETB LCDEN 				;SETS LCD ENABLE PIN 
    ACLRB LCDEN					;RESETS LCD ENABLE PIN TO TRIGGER FALLING CLOCK PULSE
    CALL DELAY_20MS				;DELAY OF 20MS FOR LCD TO RECIEVE DATA
    POPALL
ENDM


PRINT_T MACRO DAT
    ASETB LCDRS						;SETS LCD RESET PIN FOR DATA 
    PUSHALL							;
    MOV AL, DAT			
    MOV DX, A8255+00H
    OUT DX, AL
    ASETB LCDEN
    ACLRB LCDEN
    POPALL    

ENDM

         
PRINT_H MACRO DAT		;Macro for Printing for Humidity 
    ASETB LCDRS
    PUSHALL
    MOV AL, DAT
    MOV DX, A8255+00H
    OUT DX, AL
    ASETB LCDEN
    ACLRB LCDEN
    POPALL    

ENDM

PRINT_P MACRO DAT	   ;Macro for Printing for Pressure 
    ASETB LCDRS
    PUSHALL
    MOV AL, DAT
    MOV DX, A8255+00H
    OUT DX, AL
    ASETB LCDEN
    ACLRB LCDEN
    POPALL    

ENDM

LCD_CLEAR MACRO
    LCD_OUT 01H
ENDM
 

DIV_ROT MACRO  INP 			;Macros to Divide since DIV command  gave error 
    
    PUSHALL
    MOV CX, 00
    MOV BX, INP
    
    LOOPT:
    SUB AX, BX
	INC CX
    CMP AX, 0
    JGE LOOPT

	DEC CX
	ADD AX, BX
	
	MOV R, AL
	MOV Q, CL

	POPALL
ENDM

          
DIV_ROTH MACRO  INP
    
    PUSHALL
    MOV CX, 00
    MOV BX, INP
    
    LOOPH:
    SUB AX, BX
	INC CX
    CMP AX, 0
    JGE LOOPH

	DEC CX
	ADD AX, BX
	
	MOV R, AL
	MOV Q, CL

	POPALL
ENDM

DIV_ROTP MACRO  INP
    
    PUSHALL
    MOV CX, 00
    MOV BX, INP
    
    LOOPP:
    SUB AX, BX
	INC CX
    CMP AX, 0
    JGE LOOPP

	DEC CX
	ADD AX, BX
	
	MOV R, AL
	MOV Q, CL

	POPALL
ENDM

;------------------------START-PROCEDURE DEFS-----------------------;

DELAY_20MS PROC NEAR		;Procedure to Set a delay of 20ms
    MOV DX, 10
R1: MOV CX, 2353
R2: LOOP R2
    DEC DX
    JNE R1
    RET     
DELAY_20MS ENDP

PRINT_STR_T PROC NEAR   ;Print the String for Temperature 
    LEA SI, T_DISP
    MOV CL, T_CNT
REPEATT: PRINT_T [SI] 
    INC SI
    LOOP REPEATT
    RET
PRINT_STR_T ENDP


PRINT_STR_H PROC NEAR    ;Print the String for Humidity
    LEA SI, H_DISP
    MOV CL, H_CNT
REPEATH: PRINT_H [SI] 		
    INC SI
    LOOP REPEATH
    RET
PRINT_STR_H ENDP


PRINT_STR_P PROC NEAR   ;Print the String for Pressure
    LEA SI, P_DISP
    MOV CL, P_CNT
REPEATP: PRINT_P [SI]
    INC SI
    LOOP REPEATP
    RET
PRINT_STR_P ENDP


;Subroutines for Scaling the Various Components 

CONVERT_HUMI PROC NEAR
    
    ;GET IT TO SCALE (0-99%)
    MOV AH, 00H
    MOV AL, Q
    MOV BL, 99D            
    MUL BL
    MOV BL, 0FFH            ;FFH IS THE MAX O/P FROM ADC
    DIV BL
	
    
    ;SPLIT THE NUMBERS                        
    MOV AH, 00H
    MOV BL, 10D
    DIV BL
    
    LEA SI, NUMSTR          ;LOAD APPROPRIATE ASCII VALUE(QUO)
    ADD AX, 3030H
    MOV [SI], AL
    MOV [SI+1], AH 
    
    MOV AL, R
    MOV AH, 00H
    
    MOV BX, 100D
    MUL BX
    MOV BL, 12D
    DIV BL
    
    MOV AH, 00H
    MOV BL, 10D
    DIV BL
    ADD AX, 3030H
    
    MOV [SI+2], AL      ;LOAD APPROPRIATE ASCII VALUE(REM)
    MOV [SI+3], AH
   
    RET

CONVERT_HUMI ENDP


CONVERT_TEMP PROC NEAR 			;Subroutine for Scaling Temperature
    
    ;GET IT TO SCALE (5-50 C)
    MOV AH, 00H
    MOV AL, Q
    MOV BL, 45D
    MUL BL
    MOV BL, 0FFH
    DIV BL
	ADD AX, 05H
    
    ;SPLIT THE NUMBERS                     
    MOV AH, 00H
    MOV BL, 10D
    DIV BL
    
    LEA SI, NUMSTR
    ADD AX, 3030H
    MOV [SI], AL
    MOV [SI+1], AH 
    
    MOV AL, R
    MOV AH, 00H
    
    MOV BX, 100D
    MUL BX
    MOV BL, 12D
    DIV BL
    
    MOV AH, 00H
    MOV BL, 10D
    DIV BL
    ADD AX, 3030H
    
    MOV [SI+2], AL
    MOV [SI+3], AH
   
    RET

CONVERT_TEMP ENDP



CONVERT_PRES PROC NEAR				;Subroutine for Scaling Pressure 
    
    ;GET IT TO SCALE (0-2 BAR)
    MOV AH, 00H
    MOV AL, Q
    MOV BL, 02D            
    MUL BL
    MOV BL, 0FFH            ;FFH IS THE MAX O/P FROM ADC
    DIV BL
	
    
    ;SPLIT THE NUMBERS                        
    MOV AH, 00H
    MOV BL, 10D
    DIV BL
    
    LEA SI, NUMSTR          ;LOAD APPROPRIATE ASCII VALUE(QUO)
    ADD AX, 3030H
    MOV [SI], AL
    MOV [SI+1], AH 
    
    MOV AL, R
    MOV AH, 00H
    
    MOV BX, 100D
    MUL BX
    MOV BL, 12D
    DIV BL
    
    MOV AH, 00H
    MOV BL, 10D
    DIV BL
    ADD AX, 3030H
    
    MOV [SI+2], AL      ;LOAD APPROPRIATE ASCII VALUE(REM)
    MOV [SI+3], AH
   
    RET

CONVERT_PRES ENDP


;OUTPUT ASCII EQUIV VALUES ON LCD FROM MEM LOCATION

DATOUT_T PROC NEAR
    
    LCD_OUT 01H
    CALL PRINT_STR_T
    
    MOV AL, NUMSTR
    MOV AH, NUMSTR+1
    PRINT_T AL
    PRINT_T AH
    PRINT_T '.'
    MOV AL, NUMSTR+2
    MOV AH, NUMSTR+3
    
    PRINT_T AL
    PRINT_T AH
    RET     
    
DATOUT_T ENDP


;OUTPUT ASCII EQUIV VALUES ON LCD FROM MEM LOCATION
DATOUT_H PROC NEAR
    
    PRINT_T 01H
    CALL PRINT_STR_H
    
    MOV AL, NUMSTR
    MOV AH, NUMSTR+1
    PRINT_H AL
    PRINT_H AH
    PRINT_H '.'
    MOV AL, NUMSTR+2
    MOV AH, NUMSTR+3
    
    PRINT_H AL
    PRINT_H AH
    RET     
    
DATOUT_H ENDP

DATOUT_P PROC NEAR
    
    PRINT_T 01H
    CALL PRINT_STR_P
    
    MOV AL, NUMSTR
    MOV AH, NUMSTR+1
    PRINT_P AL
    PRINT_P AH
    PRINT_P '.'
    MOV AL, NUMSTR+2
    MOV AH, NUMSTR+3
    
    PRINT_P AL
    PRINT_P AH
    RET     
    
DATOUT_P ENDP

; ------------------------- END OF PROCEDURE DEFS --------------------------;

;------------------------START OF ISRS-----------------------;

;5 MINUTE INTERRUPT
ISR1:

	; FIRST MAKE OE HIGH PC1
	BSETB ADCOE


    CMP THP,00H
    JNZ HUMIISR1

	;ASSUMING THAT CBA IS CONNECTED TO PC 4-3-2
	;SELECT CHANNEL 000
	BCLRB ADCA
	BCLRB ADCB
	BCLRB ADCC

	;NOW MAKE A HIGH-LOW PULSE ON ALE;PC5
	BSETB ADCALE
	BCLRB ADCALE

	;HIGH-LOW PULSE ON SOC - CONNECTED TO PC0
	BSETB ADCST
	BCLRB ADCST

	;NOW WAIT FOR EOC INTERRUPT
    JMP ISR1END

    HUMIISR1:           ; THP == 1
    CMP THP,01H
    JNZ PRESISR1

    ;SELECT CHANNEL 001
	BSETB ADCA
	BCLRB ADCB
	BCLRB ADCC

	;NOW MAKE A HIGH-LOW PULSE ON ALE;PC5
	BSETB ADCALE
	BCLRB ADCALE

	;HIGH-LOW PULSE ON SOC - CONNECTED TO PC0
	BSETB ADCST
	BCLRB ADCST

    JMP ISR1END

    PRESISR1:

    ;SELECT CHANNEL 010
	BCLRB ADCA
	BSETB ADCB
	BCLRB ADCC

	;NOW MAKE A HIGH-LOW PULSE ON ALE;PC5
	BSETB ADCALE
	BCLRB ADCALE

	;HIGH-LOW PULSE ON SOC - CONNECTED TO PC0
	BSETB ADCST
	BCLRB ADCST

	

ISR1END:
    
IRET


;EOC INTERRUPT
ISR3:

    CMP THP,00H
    JNZ HUMIISR3


	MOV DX, B8255+02H
	IN AL, DX

	;FINALLY MAKE OE LOW
	BCLRB ADCOE


	CMP T_FLAG, 0
	JNZ X4
	;FOR THE FIRST HOUR, FLAGCNT = 0; FOR CONSECUTIVE ITERATIONS, IT'LL BE >0

	MOV BX, CTR
	LEA SI, VALS 
	  
	MOV [SI+BX], AL
	INC BX
	MOV CTR, BX
	CMP BX, 12
	JNZ X5

	MOV T_FLAG, 1
	MOV CTR, 0
	JMP ENDISR1

	X4:	MOV BX, CTR
	LEA SI, VALS
	MOV [SI+BX], AL
	INC BX
	CMP BX, 12
	JNZ X5
	MOV BX, 0

	X5:	MOV CTR, BX

    JMP ENDISR1

    HUMIISR3:       ;THP == 1
    CMP THP,01H
    JNZ PRESISR3

    
	MOV DX, B8255+02H
	IN AL, DX

	;FINALLY MAKE OE LOW
	BCLRB ADCOE


	CMP H_FLAG, 0
	JNZ X41

	MOV BX, CTR11
	LEA SI, VALS11 
	  
	MOV [SI+BX], AL
	INC BX
	MOV CTR11, BX
	CMP BX, 12
	JNZ X51

	MOV H_FLAG, 1
	MOV CTR11, 0
	JMP ENDISR1

	X41:	MOV BX, CTR11
	LEA SI, VALS11
	MOV [SI+BX], AL
	INC BX
	CMP BX, 12
	JNZ X51
	MOV BX, 0

	X51:	MOV CTR11, BX
    JMP ENDISR1

    PRESISR3:

    
	MOV DX, B8255+02H
	IN AL, DX

	;FINALLY MAKE OE LOW
	BCLRB ADCOE


	CMP P_FLAG, 0
	JNZ X411
	

	MOV BX, CTR111
	LEA SI, VALS111 
	  
	MOV [SI+BX], AL
	INC BX
	MOV CTR111, BX
	CMP BX, 12
	JNZ X511

	MOV P_FLAG, 1
	MOV CTR111, 0
	JMP ENDISR1

	X411:	MOV BX, CTR111
	LEA SI, VALS111
	MOV [SI+BX], AL
	INC BX
	CMP BX, 12
	JNZ X511
	MOV BX, 0

	X511:	MOV CTR111, BX
	 
	ENDISR1:
IRET

;1HR INT 
ISR2:

CMP THP,00H
JNZ HUMIISR2

	MOV BX, 00H
	MOV CX, 12D
	LEA SI, VALS

	XADD:
	MOV DL, [SI]
	MOV DH, 00H
	ADD BX, DX
	INC SI
	DEC CX
	JNZ XADD
	MOV AX, BX

	MOV DX, T_FLAG
	CMP DX, 1
	JNZ X2

	MOV DIVBY, 12D
	JMP X3

	X2:
	MOV DX, CTR
	MOV DIVBY, DX
	X3:

	DIV_ROT DIVBY 

	CALL CONVERT_TEMP
	CALL DATOUT_T

JMP ENDISR2:

    HUMIISR2:
    CMP THP,01H
    JNZ PRESISR2

	MOV BX, 00H
	MOV CX, 12D
	LEA SI, VALS11

	XADD1:
	MOV DL, [SI]
	MOV DH, 00H
	ADD BX, DX
	INC SI
	DEC CX
	JNZ XADD1
	MOV AX, BX

	MOV DX, H_FLAG
	CMP DX, 1
	JNZ X21

	MOV DIVBY, 12D
	JMP X31

	X21:
	MOV DX, CTR11
	MOV DIVBY, DX
	X31:

	DIV_ROTH DIVBY 

	CALL CONVERT_HUMI
	CALL DATOUT_H
    JMP ENDISR2

    PRESISR2:

    
	MOV BX, 00H
	MOV CX, 12D
	LEA SI, VALS111

	XADD11:
	MOV DL, [SI]
	MOV DH, 00H
	ADD BX, DX
	INC SI
	DEC CX
	JNZ XADD11
	MOV AX, BX

	MOV DX, P_FLAG
	CMP DX, 1
	JNZ X211

	MOV DIVBY, 12D
	JMP X311

	X211:
	MOV DX, CTR111
	MOV DIVBY, DX
	X311:

	DIV_ROTP DIVBY 

	CALL CONVERT_PRES
	CALL DATOUT_P

ENDISR2:

IRET 
 
;BUTTON INTERRUPT
ISR0:
	MOV UPDATENOW, 01H
IRET  

;-----------------------END OF ISRS------------------------;

QUIT:
HLT


