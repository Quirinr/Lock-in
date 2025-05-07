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


#INCLUDE ADwinPro_all.Inc

'used for all channels
DIM DATA_3[400] as float 'filter parameters
DIM DATA_4[200000] as float 'plain reference frequency for mixing
DIM DATA_8[200000] as float 'harmonic of plain reference frequency for mixing
DIM DATA_11[8] as long 'ADC gains
DIM DATA_15[8] as long 'IV gains
DIM DATA_10[8] as long 'read Data catch of channels
DIM DATA_16[16] as float 'readout constants and shifts
DIM DATA_17[8] as float 'summed up inputs of channels

'CHANNEL 1
DIM DATA_2[400] as float 'measured and mixed data inphase
DIM DATA_7[400] as float 'measured and mixed data quadrature
DIM DATA_6[400] as float 'inphase filtered signal
DIM DATA_5[400] as float 'quadrature filtered signal
DIM DATA_9[400] as float 'measured and mixed data inphase harmonic
DIM DATA_12[400] as float 'measured and mixed data quadrature harmonic
DIM DATA_13[400] as float 'inphase filtered signal harmonic
DIM DATA_14[400] as float 'quadrature filtered signal harmonic

'CHANNEL 2



DIM avgcounter as long
DIM bin1 as long
DIM output_min, output_max, bin_size as float
DIM i as long 'for loop counter

DIM cosine_index as long
DIM cosine_index_harm as long
DIM idx1 as long
DIM idx2 as long
DIM idx3 as long
DIM idx4 as long
DIM save_index as long
DIM timecounter as long

INIT:
  'initialize counters and vectors
  avgcounter = 0
  
  'convert bin to V
  output_min = -10
  output_max = 9.99969
  bin_size = (output_max - output_min) / ((2^PAR_10))
  
  'calculations outside event block
  FOR i = 0 TO 7
    'DATA_16 is the readout constant in the first 8 entries and the outmin shift in the last 8
    DATA_16[i] = bin_size * (10^(-DATA_15[i])) / ((2^DATA_11[i]) * 64 * PAR_21) 'the power of 2 represents the ADC gain
    DATA_16[8+i] = output_min * (10^(-DATA_15[i])) / (2^(DATA_11[i]))  'the power of 2 represents the ADC gain
  NEXT
  
  
  'ADJUST THIS TO FIXED FILTER ORDER
  'sets filter order 
  PAR_19 = 5 'par19 acts as filtering index
  
  'initializes arrays for filtering
  FOR i = 0 TO 72
    DATA_2[i] = 0
    DATA_7[i] = 0
    DATA_9[i] = 0
    DATA_12[i] = 0
    DATA_6[i] = 0
    DATA_5[i] = 0
    DATA_13[i] = 0
    DATA_14[i] = 0
    
    'ADD NEW ARRAYS
  NEXT
  DATA_17[0] = 0
  DATA_17[1] = 0
  DATA_17[2] = 0
  DATA_17[3] = 0
  DATA_17[4] = 0
  DATA_17[5] = 0
  DATA_17[6] = 0
  DATA_17[7] = 0
  
  idx1 = 4
  idx2 = 3
  idx3 = 2
  idx4 = 1
  
  ' start first conversion
  P2_START_CONVF(Par_5, 0000000011111111b)'<---- whats this bin for
  P2_WAIT_EOC(11b)
  
EVENT:
  'this is where the input will be read
  
  'if does not work change back to 1!v
  P2_Read_ADCF8_24B(PAR_5, DATA_10, 0) 'whats the 3. input for? 
  P2_START_CONVF(Par_5, 0000000011111111b) 'there was 11b
  
  'here the input gets summed up for each channel
  DATA_17[0] = DATA_17[0] + DATA_10[0]
  DATA_17[1] = DATA_17[1] + DATA_10[1]
  DATA_17[2] = DATA_17[2] + DATA_10[2]
  DATA_17[3] = DATA_17[3] + DATA_10[3]
  DATA_17[4] = DATA_17[4] + DATA_10[4]
  DATA_17[5] = DATA_17[5] + DATA_10[5]
  DATA_17[6] = DATA_17[6] + DATA_10[6]
  DATA_17[7] = DATA_17[7] + DATA_10[7]
  
  avgcounter = avgcounter + 1

  'get averaging
  IF(avgcounter = PAR_21) THEN
    
    'here the averaging and other operations happen: summed inputs * constant1 + constant2 (constants calculated in INIT)
    DATA_17[0] = (DATA_17[0] * DATA_16[0]) + DATA_16[8]
    DATA_17[1] = (DATA_17[1] * DATA_16[1]) + DATA_16[9]
    DATA_17[2] = (DATA_17[2] * DATA_16[2]) + DATA_16[10]
    DATA_17[3] = (DATA_17[3] * DATA_16[3]) + DATA_16[11]
    DATA_17[4] = (DATA_17[4] * DATA_16[4]) + DATA_16[12]
    DATA_17[5] = (DATA_17[5] * DATA_16[5]) + DATA_16[13]
    DATA_17[6] = (DATA_17[6] * DATA_16[6]) + DATA_16[14]
    DATA_17[7] = (DATA_17[7] * DATA_16[7]) + DATA_16[15] 
    
    'the averaged data gets mixed and some initialization steps of the filtering happens, also for the harmonic

    cosine_index = PAR_25 + PAR_28
    cosine_index_harm = PAR_25 + PAR_28
      
    'CHANNEL 1
    DATA_2[PAR_19]= DATA_17[1] * DATA_4[PAR_25] 'mixing with plain sine
    DATA_7[PAR_19]= DATA_17[1] * DATA_4[cosine_index] 'mixing with plain cos
    DATA_9[PAR_19]= DATA_17[1] * DATA_8[PAR_25] 'mixing with harmonic sine
    DATA_12[PAR_19]= DATA_17[1] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    
    'realtime filtering
    idx1 = PAR_19 -1
    idx2 = PAR_19 -2
    idx3 = PAR_19 -3
    idx4 = PAR_19 -4
    DATA_6[PAR_19] = DATA_3[0]*DATA_2[PAR_19] + DATA_3[1]*DATA_2[idx1] + DATA_3[2]*DATA_2[idx2] + DATA_3[3]*DATA_2[idx3] + DATA_3[4]*DATA_2[idx4] - DATA_3[6]*DATA_6[idx1] - DATA_3[7]*DATA_6[idx2] - DATA_3[8]*DATA_6[idx3] - DATA_3[9]*DATA_6[idx4]
    DATA_5[PAR_19] = DATA_3[0]*DATA_7[PAR_19] + DATA_3[1]*DATA_7[idx1] + DATA_3[2]*DATA_7[idx2] + DATA_3[3]*DATA_7[idx3] + DATA_3[4]*DATA_7[idx4] - DATA_3[6]*DATA_5[idx1] - DATA_3[7]*DATA_5[idx2] - DATA_3[8]*DATA_5[idx3] - DATA_3[9]*DATA_5[idx4]
    DATA_13[PAR_19] = DATA_3[0]*DATA_9[PAR_19] + DATA_3[1]*DATA_9[idx1] + DATA_3[2]*DATA_9[idx2] + DATA_3[3]*DATA_9[idx3] + DATA_3[4]*DATA_9[idx4] - DATA_3[6]*DATA_13[idx1] - DATA_3[7]*DATA_13[idx2] - DATA_3[8]*DATA_13[idx3] - DATA_3[9]*DATA_13[idx4]
    DATA_14[PAR_19] = DATA_3[0]*DATA_12[PAR_19] + DATA_3[1]*DATA_12[idx1] + DATA_3[2]*DATA_12[idx2] + DATA_3[3]*DATA_12[idx3] + DATA_3[4]*DATA_12[idx4] - DATA_3[6]*DATA_14[idx1] - DATA_3[7]*DATA_14[idx2] - DATA_3[8]*DATA_14[idx3] - DATA_3[9]*DATA_14[idx4]

     
    DATA_2[idx4]= DATA_2[PAR_19] 'for continous filtering, whenever you reset PAR_19
    DATA_7[idx4]= DATA_7[PAR_19] 'for continous filtering, whenever you reset PAR_19
    DATA_9[idx4]= DATA_9[PAR_19] 'for continous filtering, whenever you reset PAR_19
    DATA_12[idx4]= DATA_12[PAR_19] 'for continous filtering, whenever you reset PAR_19
    
    DATA_6[idx4] = DATA_6[PAR_19]
    DATA_5[idx4] = DATA_5[PAR_19]
    DATA_13[idx4] = DATA_13[PAR_19]
    DATA_14[idx4] = DATA_14[PAR_19]
      
    avgcounter = 0
    DATA_17[0] = 0
    DATA_17[1] = 0
    DATA_17[2] = 0
    DATA_17[3] = 0
    DATA_17[4] = 0
    DATA_17[5] = 0
    DATA_17[6] = 0
    DATA_17[7] = 0
    
    PAR_19 = (PAR_19+1) AND 3 'trick to prevent if: through the bitwise AND it serves as a modulo
    PAR_19 = PAR_19 + 4

  ENDIF
FINISH:
