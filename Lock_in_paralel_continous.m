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

Timetrace.scanrate = 500000;       % Hz
Timetrace.points_av = 100;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_multi_continous';

%% Initialize
Settings = Init(Settings);
%% Initialize ADwin
Settings = Init_ADwin(Settings, Waveform, Timetrace);

%% set up sinewave

f_wanted = 12;
phi_shift = 0; %phase shift in degrees
Amplitude = 1;
wave_vec_length = 2000;

q = 1:wave_vec_length;
wave = Amplitude * sqrt(2) * cos(q*2*pi/wave_vec_length + phi_shift*2*pi/360);
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

harmonic = 2;   %IDEA: try demodulating harmonic with harmonic reference instead of normal one with DATA_2 abd 7 to localize the problem
cutoff = 1;
order = 4;

[b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');

%subtracts the shift introduced by uneven zero order hold error
q = 1:4*wave_vec_length;
q = q - Settings.clockfrequency/(Processdelay6 * Timetrace.sampling_rate); % q - (fsett/fmeasure)/2
internal_reference_wave =  sqrt(2) * cos(q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing
internal_reference_wave_harm =  sqrt(2) * cos(harmonic*q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing with harmonic
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
fig = uifigure('Name', ['Channel:', ' x'], 'Position', [100, 100, 600, 700]);

% Number of channels
numChannels = 8;

% Preallocate label arrays
labels = gobjects(numChannels, 4); % 4 parameters: I, Q, R, Theta

% Create labels
for i = 1:numChannels
    y_offset = 650 - (i-1)*80; % spacing between channel blocks
    labels(i, 1) = uilabel(fig, 'Position', [20, y_offset, 560, 20], ...
        'Text', sprintf('Ch %d Inphase: ', i));
    labels(i, 2) = uilabel(fig, 'Position', [20, y_offset - 20, 560, 20], ...
        'Text', sprintf('Ch %d Quadrature: ', i));
    labels(i, 3) = uilabel(fig, 'Position', [20, y_offset - 40, 560, 20], ...
        'Text', sprintf('Ch %d R: ', i));
    labels(i, 4) = uilabel(fig, 'Position', [300, y_offset - 40, 560, 20], ...
        'Text', sprintf('Ch %d Theta (deg): ', i));
end

% Set harmonic number for display (adjust as needed)

while isvalid(fig)
    idx = Get_Par(19);


    % Get main signals
    I = GetData_Double(6, idx, 1);
    Q = GetData_Double(5, idx, 1);
    R = sqrt(I.^2 + Q.^2);
    Theta = atan2(Q, I) * 180 / pi;

    % Get harmonic signals
    I_harm = GetData_Double(13, idx, 1);
    Q_harm = GetData_Double(14, idx, 1);
    R_harm = sqrt(I_harm.^2 + Q_harm.^2);
    Theta_harm = atan2(Q_harm, I_harm) * 180 / pi;

    % Update labels
    labels(1,1).Text = sprintf('Ch %d Inphase: %.5f    %d. Harm: %.5f', 1, I, harmonic, I_harm);
    labels(1,2).Text = sprintf('Ch %d Quadrature: %.5f %d. Harm: %.5f', 1, Q, harmonic, Q_harm);
    labels(1,3).Text = sprintf('R: %.5f                   %d. Harm: %.5f', R, harmonic, R_harm);
    labels(1,4).Text = sprintf('Theta (deg): %.2f         %d. Harm: %.2f', Theta, harmonic, Theta_harm);

    for i = 2:numChannels
        % Base channel index offset
        base = (i - 2) * 8;

        % Get main signals
        I = GetData_Double(20 + base, idx, 1);
        Q = GetData_Double(21 + base, idx, 1);
        R = sqrt(I.^2 + Q.^2);
        Theta = atan2(Q, I) * 180 / pi;

        % Get harmonic signals
        I_harm = GetData_Double(24 + base, idx, 1);
        Q_harm = GetData_Double(25 + base, idx, 1);
        R_harm = sqrt(I_harm.^2 + Q_harm.^2);
        Theta_harm = atan2(Q_harm, I_harm) * 180 / pi;

        % Update labels
        labels(i,1).Text = sprintf('Ch %d Inphase: %.5f    %d. Harm: %.5f', i, I, harmonic, I_harm);
        labels(i,2).Text = sprintf('Ch %d Quadrature: %.5f %d. Harm: %.5f', i, Q, harmonic, Q_harm);
        labels(i,3).Text = sprintf('R: %.5f                   %d. Harm: %.5f', R, harmonic, R_harm);
        labels(i,4).Text = sprintf('Theta (deg): %.2f         %d. Harm: %.2f', Theta, harmonic, Theta_harm);
    end

    pause(0.1);
end