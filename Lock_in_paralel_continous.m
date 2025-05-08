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

Waveform.process = 'Waveform_AO';

Timetrace.scanrate = 50000;       % Hz
Timetrace.points_av = 10;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_multi_continous';

%% Initialize
Settings = Init(Settings);
%% Initialize ADwin
Settings = Init_ADwin(Settings, Waveform, Timetrace);

%% set up sinewave

f_wanted = 34;
phi_shift = 0; %phase shift in degrees
Amplitude = 1;
wave_vec_length = 2000;

q = 1:wave_vec_length;
wave = Amplitude * sqrt(2) * sin(q*2*pi/wave_vec_length + phi_shift*2*pi/360);
wave_bin = convert_V_to_bin(wave, Settings.output_min, Settings.output_max, Settings.output_resolution);

Processdelay6 = round(Settings.clockfrequency/(wave_vec_length * f_wanted));
actual_f_wanted = Settings.clockfrequency/(wave_vec_length * Processdelay6);
fprintf("actual frequency = %f \n", actual_f_wanted)
Set_Processdelay(6, Processdelay6);

SetData_Double(1, wave_bin, 0);
Set_Par(23, numel(wave_bin));
Set_Par(6, Settings.AO_address);

%% set up timetrace

% set parameters 
[Timetrace.process_delay, ~] = get_delays(Timetrace.scanrate, 0, Settings.clockfrequency);  % get_delays
Timetrace.time_per_point = Timetrace.points_av / Timetrace.scanrate; % 1/sampling rate
Timetrace.sampling_rate = 1 / Timetrace.time_per_point;
Set_Processdelay(2, Timetrace.process_delay);

% create time vector
%Timetrace.time.ADwin = (0:Timetrace.time_per_point:(Timetrace.runtime_counts-1)*Timetrace.time_per_point)';

% set ADCs
Set_Par(10, Settings.input_resolution);

% set addresses
Set_Par(5,Settings.AI_address);
Set_Par(7,Settings.DIO_address);


% set amplifier settings
IV_gains = [0, 0, 0, 0, 0, 0, 0, 0]; %it will be calculated as 10^(-gain)
SetData_Double(15, IV_gains, 0);

% Inputs timetrace
Set_Par(21, Timetrace.points_av);

%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 0);

%% run sine
Start_Process(6);

%% set realtime filering parameters

harmonic = 15;   %IDEA: try demodulating harmonic with harmonic reference instead of normal one with DATA_2 abd 7 to localize the problem
cutoff = 1;
order = 4;

[b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');

%subtracts the shift induced by averaging
q = 0:4*wave_vec_length;
q = q - round(Settings.clockfrequency/(Processdelay6 * Timetrace.sampling_rate * 2)); % q - (fsett/fmeasure)/2
internal_reference_wave =  sqrt(2) * sin(q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing
internal_reference_wave_harm =  sqrt(2) * sin(harmonic*q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing with harmonic
%shiftpar = Settings.clockfrequency/(Processdelay6 * Timetrace.sampling_rate * 2)


Set_Par(28, round(wave_vec_length/4));
Set_Par(31, round(wave_vec_length/(4*harmonic)));
SetData_Double(3, [b, a], 0); %set filter parameters
SetData_Double(4, internal_reference_wave, 0); %defines normalized reference for mixing, multiple length to simplify cosine in ADBASIC
SetData_Double(8, internal_reference_wave_harm, 0); %defines normailzed harmonic reference for mixing, multiple length to simplify cosine in ADBASIC

%% run timetrace
Start_Process(2);

%% ADWIN readout and plot

% Create UI figure
fig = uifigure('Name', ['Channel:', ' x'], 'Position', [100, 100, 400, 200]);

% Create labels for the 4 parameters
label1 = uilabel(fig, 'Position', [20 120 400 20], 'Text', 'filtered_signal_inphase: ');
label2 = uilabel(fig, 'Position', [20 90 400 20], 'Text', 'filtered_signal_quadrature: ');
label3 = uilabel(fig, 'Position', [20 60 400 20], 'Text', 'R: ');
label4 = uilabel(fig, 'Position', [20 30 400 20], 'Text', 'Theta: ');


while isvalid(fig)

    idx = Get_Par(19);
    filtered_signal_inphase = GetData_Double(68, idx, 1);
    filtered_signal_quadrature = GetData_Double(69, idx, 1);
    R = sqrt(filtered_signal_inphase.^2 + filtered_signal_quadrature.^2);
    Theta = atan2(filtered_signal_quadrature , filtered_signal_inphase)*360/(2*pi);

    filtered_signal_inphase_harm = GetData_Double(72, idx, 1);
    filtered_signal_quadrature_harm = GetData_Double(73, idx, 1);
    R_harm = sqrt(filtered_signal_inphase_harm.^2 + filtered_signal_quadrature_harm.^2);
    Theta_harm = atan2(filtered_signal_quadrature_harm , filtered_signal_inphase_harm)*360/(2*pi);


    % Update labels
    label1.Text = sprintf('inphase: %.5f                 %d. Harmonic: %.5f', filtered_signal_inphase, harmonic, filtered_signal_inphase_harm);
    label2.Text = sprintf('quadrature: %.5f              %d. Harmonic: %.5f', filtered_signal_quadrature, harmonic, filtered_signal_quadrature_harm);
    label3.Text = sprintf('R: %.5f                       %d. Harmonic: %.5f', R, harmonic, R_harm);
    label4.Text = sprintf('Theta (deg): %.5f             %d. Harmonic: %.5f', Theta, harmonic, Theta_harm);

    % Wait
    pause(0.1);
end