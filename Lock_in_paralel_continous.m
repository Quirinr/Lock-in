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

Timetrace.scanrate = 500000;       % Hz
Timetrace.points_av = 100;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_single_continous';

%% Initialize
Settings = Init(Settings);
%% Initialize ADwin
Settings = Init_ADwin(Settings, Waveform, Timetrace);

%% set up sinewave

f_wanted = 70;
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
Set_Par(8, Waveform.output);
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
Set_FPar(27, 0);

% Inputs timetrace
Set_Par(21, Timetrace.points_av);

%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 1);

%% run sine
Start_Process(6);

%% set realtime filering parameters

harmonic = 2;
cutoff = 1;
order = 4;

[b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');

%subtracts the shift induced by averaging
q = 1:3*wave_vec_length;
q = q - round(Settings.clockfrequency/(Processdelay6 * Timetrace.sampling_rate * 2)); % q - (fsett/fmeasure)/2
internal_reference_wave =  sqrt(2) * sin(q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing
internal_reference_wave_harm =  sqrt(2) * sin(harmonic*q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing with harmonic
%shiftpar = Settings.clockfrequency/(Processdelay6 * Timetrace.sampling_rate * 2)

Set_Par(28, round(wave_vec_length/4));
Set_Par(29, order);
SetData_Double(3, [b, a], 0); %set filter parameters
SetData_Double(4, internal_reference_wave, 0); %defines normalized reference for mixing, multiple length to simplify cosine in ADBASIC
SetData_Double(8, internal_reference_wave_harm, 0); %defines normailzed harmonic reference for mixing, multiple length to simplify cosine in ADBASIC
SetData_Double(2, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_2 to 0 for filtering purposes
SetData_Double(5, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_5 to 0 for filtering purposes
SetData_Double(6, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_6 to 0 for filtering purposes
SetData_Double(7, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_7 to 0 for filtering purposes

SetData_Double(9, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_2 to 0 for filtering purposes
SetData_Double(14, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_5 to 0 for filtering purposes
SetData_Double(13, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_6 to 0 for filtering purposes
SetData_Double(12, zeros(2*order + 1), 0); %sets the first 4 entries of DATA_7 to 0 for filtering purposes

%% run timetrace
Start_Process(2);

%% ADWIN readout and plot

% Create UI figure
fig = uifigure('Name', 'Live Parameters', 'Position', [100 100 300 200]);
fig2 = uifigure('Name', 'Live Parameters harmonic', 'Position', [500 500 300 200]);

% Create labels for the 4 parameters
label1 = uilabel(fig, 'Position', [20 120 260 20], 'Text', 'filtered_signal_inphase: ');
label2 = uilabel(fig, 'Position', [20 90 260 20], 'Text', 'filtered_signal_quadrature: ');
label3 = uilabel(fig, 'Position', [20 60 260 20], 'Text', 'R: ');
label4 = uilabel(fig, 'Position', [20 30 260 20], 'Text', 'Theta: ');

label5 = uilabel(fig2, 'Position', [20 120 260 20], 'Text', sprintf('filtered_signal_inphase_%d_harmonic:', harmonic));

label6 = uilabel(fig2, 'Position', [20 90 260 20], 'Text', sprintf('filtered_signal_quadrature_%d_harmonic:', harmonic));

label7 = uilabel(fig2, 'Position', [20 60 260 20], 'Text', sprintf('R_%d_harmonic:', harmonic));

label8 = uilabel(fig2, 'Position', [20 30 260 20], 'Text', sprintf('Theta_%d_harmonic:', harmonic));



while isvalid(fig)
    filtered_signal_inphase = GetData_Double(6, 0, 1);
    filtered_signal_quadrature = GetData_Double(5, 0, 1);
    R = sqrt(filtered_signal_inphase.^2 + filtered_signal_quadrature.^2);
    Theta = atan2(filtered_signal_quadrature , filtered_signal_inphase)*360/(2*pi);

    filtered_signal_inphase_harm = GetData_Double(13, 0, 1);
    filtered_signal_quadrature_harm = GetData_Double(14, 0, 1);
    R_harm = sqrt(filtered_signal_inphase_harm.^2 + filtered_signal_quadrature_harm.^2);
    Theta_harm = atan2(filtered_signal_quadrature_harm , filtered_signal_inphase_harm)*360/(2*pi);



    % Update labels
    label1.Text = sprintf('filtered_signal_inphase: %.5f', filtered_signal_inphase);
    label2.Text = sprintf('filtered_signal_quadrature: %.5f', filtered_signal_quadrature);
    label3.Text = sprintf('R: %.5f', R);
    label4.Text = sprintf('Theta (degrees): %.5f', Theta);

    label5.Text = sprintf('filtered_signal_inphase_harmonic: %.5f', filtered_signal_inphase_harm);
    label6.Text = sprintf('filtered_signal_quadrature_harmonic: %.5f', filtered_signal_quadrature_harm);
    label7.Text = sprintf('R_harmonic: %.5f', R_harm);
    label8.Text = sprintf('Theta_harmonic (degrees): %.5f', Theta_harm);

    % Wait
    pause(0.1);
end
