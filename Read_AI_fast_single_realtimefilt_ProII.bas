'<ADbasic Header, Headerversion 001.001>
' Process_Number                 = 2
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
'Gt_18b: ramps voltage on AO1, recording voltage on AI 1-4

'Inputs general:
'PAR_1 = Gain DAC 1
'PAR_2 = Gain DAC 2
'PAR_3 = Gain DAC 3
'PAR_4 = Gain DAC 4
'PAR_5 = Address AIN F4/18
'PAR_6 = Address AOUT 4/16
'PAR_7 = Address DIO-32
'PAR_8 = V output channel
'PAR_10 = ADC resolution
'PAR_20 = Number of ADC pairs

'FPAR_26 = IV convert 1 autoranging 0 no, 1 lin, 2 log
'FPAR_27 = IV convert 2 autoranging 0 no, 1 lin, 2 log
'FPAR_28 = IV convert 3 autoranging 0 no, 1 lin, 2 log
'FPAR_29 = IV convert 4 autoranging 0 no, 1 lin, 2 log
'FPAR_44 = IV convert 5 autoranging 0 no, 1 lin, 2 log
'FPAR_45 = IV convert 6 autoranging 0 no, 1 lin, 2 log
'FPAR_46 = IV convert 7 autoranging 0 no, 1 lin, 2 log
'FPAR_47 = IV convert 8 autoranging 0 no, 1 lin, 2 log

'Measurement parameters:
'FPAR_1 = actual AI2 value in bin
'FPAR_2 = actual AI3 value in bin
'FPAR_3 = actual AI4 value in bin
'FPAR_4 = actual AI5 value in bin

'Inputs Gt:
'PAR_11 = initial voltage point
'PAR_12 = set voltage point
'PAR_13 = final voltage point
'PAR_14 = length of time array
'PAR_21 = no of points to average over
'PAR_22 = no of loops to wait before measure
'PAR_17 = loops to wait to limit AO rate
'PAR_18 = actual time counter
'PAR_19 = timecounter
'PAR_27 = initial phase shift to reference signal
'PAR_28 = quarter period length of reference (used for cosine)
'PAR_29 = filter order
'measureflag = measurements flag

'Outputs:
'DATA_2 = averaged AI1 bin array 
'DATA_3 = averaged AI2 bin array 
'DATA_4 = averaged AI3 bin array 
'DATA_5 = averaged AI4 bin array 
'DATA_6 = averaged AI5 bin array 
'DATA_7 = averaged AI6 bin array 
'DATA_8 = averaged AI7 bin array 
'DATA_9 = averaged AI7 bin array 

#INCLUDE ADwinPro_all.Inc
'#INCLUDE C:\Users\lab405\Desktop\Lakeshore-ADwin-GoldII\Matlab\ADwin_script\Additional_functions.Inc

DIM DATA_2[2000000] as float 'measured and mixed data inphase
DIM DATA_7[2000000] as float 'measured and mixed data quadrature
DIM DATA_5[2000000] as float 'quadrature filtered signal
DIM DATA_6[2000000] as float 'inphase filtered signal
DIM DATA_3[100] as float 'filter parameters
DIM DATA_4[200000] as float 'plain reference frequency for mixing


DIM DATA_11[8] as long
DIM DATA_10[8] as long

DIM totalcurrent1 as float
DIM avgcounter as long
DIM bin1 as long
DIM output_min, output_max, bin_size as float
DIM IV_gain1 as float
DIM ADC_gain1 as long
DIM ADC_actual_gain1 as long
DIM readout_constant as float
DIM outmin_shift as long
DIM filter_order as long
DIM i as long 'for loop counter
DIM averagemiddle as long
DIM midtime as long

INIT:
  avgcounter = 0
  PAR_19 = 4 'par19 acts as timecounter, hope this is fine
    
  'convert bin to V
  output_min = -10
  output_max = 9.99969
  bin_size = (output_max-output_min) / ((2^PAR_10))
          
  'set DIO input and outputs. 0-15 as inputs, 16-31 as outputs; 0=input, 1=output
  'P2_DigProg(PAR_7, 1100b)
    
  'ADC gains
  ADC_gain1 = DATA_11[1] 
  ADC_actual_gain1 = 2^ADC_gain1

  'set IV gain
  IV_gain1 = 10^(-1*FPAR_27)  
  
  'calculations outside event block
  readout_constant = bin_size * IV_gain1 / (ADC_actual_gain1 * 64 * PAR_21) 'already averages over Par_21
  outmin_shift = (output_min * IV_gain1) / ADC_actual_gain1 'no Par_21 within since it cancels itself out 
  
  'sets filter order
  filter_order = PAR_29 
  
  ' start first conversion
  P2_START_CONVF(Par_5, 0000000011111111b)'<---- whats this bin for
  P2_WAIT_EOC(11b)
  
EVENT:
  'this is where the input will be read
  P2_Read_ADCF8_24B(PAR_5, DATA_10, 1) 'whats the 3. input for?
  totalcurrent1 = totalcurrent1 + DATA_10[2] 'took all calculations into averaging block
  P2_START_CONVF(Par_5, 0000000011111111b) 'there was 11b
 
  avgcounter = avgcounter + 1

  ' get averaging
  IF(avgcounter = PAR_21) THEN

    FPAR_1 = (totalcurrent1 * readout_constant) + outmin_shift 'averaging (/Par_21) happens in the constants already 
    DATA_2[PAR_19]= FPAR_1 * DATA_4[PAR_25] 'mixing with plain sine + initial phase shift
    DATA_7[PAR_19]= FPAR_1 * DATA_4[PAR_25 + PAR_28] 'mixing with plain cos +initial phase shift
    
    'realtime filtering for inphase and quadrature
    DATA_6[PAR_19] = DATA_3[0]*DATA_2[PAR_19]
    DATA_5[PAR_19] = DATA_3[0]*DATA_7[PAR_19] 
    
    FOR i = 1 TO filter_order 
      DATA_6[PAR_19] = DATA_6[PAR_19] + DATA_3[i]*DATA_2[PAR_19 - i]  - DATA_3[5 + i]*DATA_6[PAR_19 - i] 
      DATA_5[PAR_19] = DATA_5[PAR_19] + DATA_3[i]*DATA_7[PAR_19 - i] - DATA_3[5 + i]*DATA_5[PAR_19 - i] 
    NEXT 
    
    totalcurrent1 = 0  
    PAR_19 = PAR_19 + 1    'Par_19 is now timecounter
    avgcounter = 0
    
    
    
    IF (PAR_19 = PAR_14+4) THEN    'Par_19 is now timecounter, +4 since it starts at 4 
      end
    ENDIF
    
  ENDIF
   
FINISH:

