%% clear
clear
close all hidden
clc
%% Settings
Settings.save_dir = 'C:\Users\quiri\UserData';         
Settings.sample = '100kOhm'; %A2-GatetoGate G0b
Settings.ADC = {1e6, 'off', 'off','off', 'off', 'off', 'off', 'off'};
Settings.auto = ''; % FEMTO
Settings.ADC_gain = [0 0 0 0 0 0 0 0]; % 2^N
Settings.get_sample_T = ''; % {'', 'Lakeshore336', 'Lakeshore325', 'Oxford_ITC'}
Settings.type = 'Waveform';
Settings.ADwin = 'ProII'; % GoldII or ProII
Settings.res4p = 0;     % 4 point measurement
Settings.T = [10];   %;

Waveform.output = 2;
Waveform.process = 'Waveform_AO';



%% Initialize ADwin
Settings = Init(Settings);
Settings = Init_ADwin(Settings, Waveform);

%% create one period sine wave vector, given processdelay and wanted freuquency
Set_Processdelay(6,6000);
Processdelay = Get_Processdelay(6);
f_wanted = 250;
f_shift = 0; %freq shift in radian 

f_process = Settings.clockfrequency/(Processdelay);
wave_vec_length = f_process/f_wanted;
wave_vec_length = round(wave_vec_length)
q = 1:wave_vec_length;
wave = sin(q*2*pi/wave_vec_length + f_shift); %NOTE: Rounding Error, TODO: calculate it


wave_bin = convert_V_to_bin(wave, Settings.output_min, Settings.output_max, Settings.output_resolution);
SetData_Double(1, wave_bin, 0);



%% set gate voltage
%fprintf('%s - Ramping Gate to %1.2fV...', datetime('now'), Gate.setV)
%Gate = Apply_fixed_voltage(Settings, Gate);
fprintf('done\n')

%% set gate sine voltage
Set_Par(6, Settings.AO_address);
Set_Par(8, Waveform.output);
Set_Par(23,numel(wave_bin));
Start_Process(6);
