'<ADbasic Header, Headerversion 001.001>
' Process_Number                 = 2
' Initial_Processdelay           = 10000
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
'PAR_8 = Number of output channels where voltage is set
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
'PAR_19 = timecounter (here no meaning besides as a filtering index)
'PAR_27 = initial phase shift to reference signal
'PAR_28 = quarter period length of reference (used for cosine)
'PAR_29 = filter order
'PAR_31 = quarter period length of harmonic reference (used for cosine)
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
'DATA_20 = output channel addresses where the voltage is set
'DATA 21 = input channel addresses

#INCLUDE ADwinPro_all.Inc
'#INCLUDE C:\Users\lab405\Desktop\Lakeshore-ADwin-GoldII\Matlab\ADwin_script\Additional_functions.Inc

DIM DATA_2[400] as float 'measured and mixed data inphase
DIM DATA_7[400] as float 'measured and mixed data quadrature
DIM DATA_6[400] as float 'inphase filtered signal
DIM DATA_5[400] as float 'quadrature filtered signal
DIM DATA_3[400] as float 'filter parameters
DIM DATA_4[200000] as float 'plain reference frequency for mixing

DIM DATA_9[400] as float 'measured and mixed data inphase harmonic
DIM DATA_12[400] as float 'measured and mixed data quadrature harmonic
DIM DATA_13[400] as float 'inphase filtered signal harmonic
DIM DATA_14[400] as float 'quadrature filtered signal harmonic
DIM DATA_8[200000] as float 'harmonic of plain reference frequency for mixing

DIM DATA_11[8] as long 'ADC gains (fuse with 23?)
DIM DATA_23[8] as long 'IV gains (fuse with 11?)
DIM DATA_10[8] as long 'read Data catch of channels

DIM DATA_21[8] as long 'input channel addresses
DIM DATA_22[16] as float 'readout constants and shifts
DIM DATA_25[8] as float 'summed up input of all channels

DIM avgcounter as long
DIM bin1 as long
DIM output_min, output_max, bin_size as float
DIM readout_constant as float
DIM outmin_shift as long
DIM filter_order as long
DIM i as long 'for loop counter
DIM j as long 'for loop counter
DIM idx as long 'temporary index
DIM reset_index as long
DIM start_index as long
DIM save_index as long
DIM shifted_timecounter as long
DIM timecounter as long

INIT:
  'initialize counters and vectors
  PAR_8 = PAR_8 -1 'PAR_8 is the number of channels used. -1 because of 0 indexing
  avgcounter = 0
  FOR i = 0 TO PAR_8
    DATA_25[i] = 0
  NEXT
  
  
  'convert bin to V
  output_min = -10
  output_max = 9.99969
  bin_size = (output_max - output_min) / ((2^PAR_10))
  
  'calculations outside event block
  FOR i = 0 TO PAR_8
    idx = DATA_21[i]
    'DATA_22 is the readout constant in the first 8 entries and the outmin shift in the last 8
    DATA_22[i] = bin_size * (10^(-DATA_23[idx])) / ((2^DATA_11[idx]) * 64 * PAR_21) 'the power of 2 represents the ADC gain
    DATA_22[8+i] = output_min * (10^(-DATA_23[idx])) / (2^(DATA_11[idx]))  'the power of 2 represents the ADC gain
  NEXT
  
  
  'sets filter order
  filter_order = PAR_29 
  start_index = filter_order + 1
  PAR_19 = start_index 'par19 acts as filtering index
  reset_index = 2*filter_order + 1
  
  'initializes arrays for filtering
  FOR i = 0 TO 8*(2*filter_order +1)
    DATA_2[i] = 0
    DATA_7[i] = 0
    DATA_9[i] = 0
    DATA_12[i] = 0
    DATA_6[i] = 0
    DATA_5[i] = 0
    DATA_13[i] = 0
    DATA_14[i] = 0
  NEXT
  
  ' start first conversion
  P2_START_CONVF(Par_5, 0000000011111111b)'<---- whats this bin for
  P2_WAIT_EOC(11b)
EVENT:
  'this is where the input will be read
  P2_Read_ADCF8_24B(PAR_5, DATA_10, 1) 'whats the 3. input for?
  P2_START_CONVF(Par_5, 0000000011111111b) 'there was 11b
  
  'here the input gets summed up for each channel
  FOR i = 0 TO PAR_8
    idx = DATA_21[i]
    DATA_25[i] = DATA_25[i] + DATA_10[idx] 'recall, DATA_21 contains input adresses
  NEXT
 
  avgcounter = avgcounter + 1

  ' get averaging
  IF(avgcounter = PAR_21) THEN
    
    'here the averaging and other operations happen
    FOR i = 0 TO PAR_8 'could be more efficient if I save outmin shift in seperate array
      DATA_25[i] = (DATA_25[i] * DATA_22[i]) + DATA_22[8+i] 'summed inputs * constant1 + constant2 (constants calculated in INIT)
    
      'the averaged data gets mixed and some initialization steps of the filtering happens, also for the harmonic
      'the results are saved in a pseudo multidimensional array, where the first 2*filter_oder +1 entries represent the first channel and so on
      'idea: could precalculate it outside and store it in an array to potentially save operations
      timecounter = PAR_19 + reset_index * i 'reset index is 2* filter_order + 1 
      shifted_timecounter = timecounter - filter_order
      
      DATA_2[timecounter]= DATA_25[i] * DATA_4[PAR_25] 'mixing with plain sine + initial phase shift
      DATA_7[timecounter]= DATA_25[i] * DATA_4[PAR_25 + PAR_28] 'mixing with plain cos +initial phase shift
    
      'the same with the harmonic
      DATA_9[timecounter]= DATA_25[i] * DATA_8[PAR_25] 'mixing with plain sine + initial phase shift
      DATA_12[timecounter]= DATA_25[i] * DATA_8[PAR_25 + PAR_31] 'mixing with plain cos +initial phase shift
    
    
      'realtime filtering for inphase and quadrature
      DATA_6[timecounter] = DATA_3[0]*DATA_2[timecounter]
      DATA_5[timecounter] = DATA_3[0]*DATA_7[timecounter]
    
      'the same for harmonic
      DATA_13[timecounter] = DATA_3[0]*DATA_9[timecounter]
      DATA_14[timecounter] = DATA_3[0]*DATA_12[timecounter]
    
      FOR j = 1 TO filter_order 
        DATA_6[timecounter] = DATA_6[timecounter] + DATA_3[j]*DATA_2[timecounter - j] - DATA_3[start_index + j]*DATA_6[timecounter - j] 'start_index because = filter_oder+1
        DATA_5[timecounter] = DATA_5[timecounter] + DATA_3[j]*DATA_7[timecounter - j] - DATA_3[start_index + j]*DATA_5[timecounter - j] 'start_index because = filter_oder+1
      
        'again the same for harmonic
        DATA_13[timecounter] = DATA_13[timecounter] + DATA_3[j]*DATA_9[timecounter - j]  - DATA_3[start_index + j]*DATA_13[timecounter - j]'start_index because = filter_oder+1
        DATA_14[timecounter] = DATA_14[timecounter] + DATA_3[j]*DATA_12[timecounter - j] - DATA_3[start_index + j]*DATA_14[timecounter - j]'start_index because = filter_oder+1
      NEXT 
      
      DATA_2[shifted_timecounter]= DATA_2[timecounter] 'for continous filtering, whenever you reset PAR_19
      DATA_7[shifted_timecounter]= DATA_7[timecounter] 'for continous filtering, whenever you reset PAR_19
      DATA_9[shifted_timecounter]= DATA_9[timecounter] 'for continous filtering, whenever you reset PAR_19
      DATA_12[shifted_timecounter]= DATA_12[timecounter] 'for continous filtering, whenever you reset PAR_19
      
      DATA_6[shifted_timecounter] = DATA_6[timecounter]
      DATA_5[shifted_timecounter] = DATA_5[timecounter]
      'the same for harmonic
      DATA_13[shifted_timecounter] = DATA_13[timecounter]
      DATA_14[shifted_timecounter] = DATA_14[timecounter]
      
      
      save_index = reset_index * i
      DATA_6[save_index] = DATA_6[timecounter]
      DATA_5[save_index] = DATA_5[timecounter]
      'the same for harmonic
      DATA_13[save_index] = DATA_13[timecounter]
      DATA_14[save_index] = DATA_14[timecounter]
    NEXT
    
    PAR_19 = PAR_19 + 1    'Par_19 is underlying timecounter
    avgcounter = 0
    
    IF (PAR_19 = reset_index) THEN
      PAR_19 = start_index
    ENDIF

    
  ENDIF
FINISH:
