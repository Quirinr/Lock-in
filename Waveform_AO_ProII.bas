'<ADbasic Header, Headerversion 001.001>
' Process_Number                 = 6
' Initial_Processdelay           = 3000
' Eventsource                    = Timer
' Control_long_Delays_for_Stop   = No
' Priority                       = High
' Version                        = 1
' ADbasic_Version                = 6.4.0
' Optimize                       = Yes
' Optimize_Level                 = 1
' Stacksize                      = 1000
' Info_Last_Save                 = Q  Q\quiri
'<Header End>
' AO1_read_AI_18b.bas: ramps voltage on AO1, recording voltage on AI 1-4

'Inputs general:
'PAR_1 = Gain DAC 1
'PAR_2 = Gain DAC 2
'PAR_3 = Gain DAC 3
'PAR_4 = Gain DAC 4
'PAR_5 = Address AIN F4/18
'PAR_6 = Address AOUT 4/16
'PAR_7 = Address DIO-32
'PAR_8 = voltage sweep output channel
'PAR_10 = ADC resolution

'Measurement parameters:
'FPAR_1 = actual AI2 value in bin
'FPAR_2 = actual AI3 value in bin
'FPAR_3 = actual AI4 value in bin
'FPAR_4 = actual AI5 value in bin

'Inputs:
'PAR_21 = no of points to average over
'PAR_22 = no of loops to wait before measure
'PAR_23 = length of voltage array
'PAR_24 = actual counter

'DATA_1 = AO1 voltage values array (maximum length 1048576, so 4 arrays can be handled in parallel)

'Outputs:
'DATA_2 = averaged AI1 bin array 
'DATA_3 = averaged AI2 bin array 
'DATA_4 = averaged AI3 bin array 
'DATA_5 = averaged AI4 bin array 
'DATA_6 = read ADC values

#INCLUDE ADwinPro_all.Inc
'#INCLUDE C:\Users\lab405\Desktop\Lakeshore-ADwin-GoldII\Matlab\ADwin_script\Additional_functions.Inc

DIM DATA_1[200000] as long     'voltage output 

DIM actual_V as long

INIT:
  PAR_25 = 0 'Par_25 acts as voltagecounter
  actual_V = DATA_1[0] 'starts at 0 since then you do not have to do Par_23 + 1 and save an operation
  
  'set DAC to first value
  P2_Write_DAC(Par_6, PAR_8, actual_V)
  P2_Start_DAC(PAR_6)
  
EVENT:
  
  'for debugging
  'PAR_24 = actual_V   
  
  'this is where the outputsine gets created
  IF (PAR_25 < PAR_23)  THEN 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, PAR_8, DATA_1[PAR_25])'Par_25 acts as voltagecounter
    P2_Start_DAC(PAR_6)
  ELSE
    PAR_25 = 0'Par_25 acts as voltagecounter
  ENDIF
    
  PAR_25 = PAR_25 + 1'Par_25 acts as voltagecounter
  
FINISH:
  P2_Write_DAC(PAR_6, PAR_8, DATA_1[PAR_25])'Par_25 acts as voltagecounter
  P2_Start_DAC(PAR_6)
