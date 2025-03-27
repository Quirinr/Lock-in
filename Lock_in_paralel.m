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

Timetrace.runtime = 50;      % s
Timetrace.scanrate = 500000;       % Hz
Timetrace.points_av = 100;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_single';
%% Initialize
Settings = Init(Settings);
%% Initialize ADwin
Settings = Init_ADwin(Settings, Waveform, Timetrace);

%% set up sinewave

Set_Processdelay(6, 2000); %500kHz on ProII, standard for timetrace
Processdelay = Get_Processdelay(6);

f_wanted = 150;      
phi_shift = 0; %phase shift in radian change to degrees

f_process = Settings.clockfrequency/(Processdelay);
wave_vec_length = f_process/f_wanted;
wave_vec_length = round(wave_vec_length)
q = 1:wave_vec_length;
wave = sin(q*2*pi/wave_vec_length + phi_shift); %NOTE: Rounding Error, TODO: calculate it
wave_bin = convert_V_to_bin(wave, Settings.output_min, Settings.output_max, Settings.output_resolution);

SetData_Double(1, wave_bin, 1);
Set_Par(8, Waveform.output);
Set_Par(23,numel(wave_bin));
Set_Par(6, Settings.AO_address);

%% set up timetrace

% set parameters
[Timetrace.process_delay, ~] = get_delays(Timetrace.scanrate, 0, Settings.clockfrequency);  % get_delays
Timetrace.process_delay;
Timetrace.time_per_point = Timetrace.points_av / Timetrace.scanrate; % 1/sampling rate
Timetrace.sampling_rate = 1 / Timetrace.time_per_point;
Timetrace.runtime_counts = ceil(Timetrace.sampling_rate * Timetrace.runtime);

% create time vector
Timetrace.time.ADwin = (0:Timetrace.time_per_point:(Timetrace.runtime_counts-1)*Timetrace.time_per_point)';

% set ADCs
Set_Par(10, Settings.input_resolution);

% set addresses
Set_Par(5,Settings.AI_address);
Set_Par(7,Settings.DIO_address);

% set amplifier settings
Set_FPar(27, 0);

% Inputs timetrace
Set_Par(14, Timetrace.runtime_counts);
Set_Par(21, Timetrace.points_av);

%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 1);
%% run sine
Start_Process(6);
%% run timetrace
Set_Processdelay(2, Timetrace.process_delay);
Start_Process(2);
Timetrace.index = 1;
%% get current and show plot
Settings.N_ADC = 1;
Settings.ADC_idx = 1; %changed it to 2 since 1 was really weird
Timetrace = Realtime_timetrace(Settings, Timetrace, Settings.type);

fprintf('done\n')

