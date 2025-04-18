%% clear
clear
close all hidden
clc
%% Settings

MODE = 1; % 0 for offline filtering, 1 for realtime filtering

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

Timetrace.runtime = 7;      % s
Timetrace.scanrate = 500000;       % Hz
Timetrace.points_av = 100;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';

if MODE == 1
    Settings.ADC_idx = 5; %the Data array number which should be print +1
    Timetrace.process = 'Read_AI_fast_single_realtimefilt';

elseif MODE == 0
    Settings.ADC_idx = 1; %the Data array number which should be print +1
    Timetrace.process = 'Read_AI_fast_single';
end
%% Initialize
Settings = Init(Settings);
%% Initialize ADwin
Settings = Init_ADwin(Settings, Waveform, Timetrace);

%% set up sinewave

f_wanted = 34;      
phi_shift = 0; %phase shift in degrees
Amplitude = 1;
wave_vec_length = 1000;

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
Timetrace.process_delay; 
Timetrace.time_per_point = Timetrace.points_av / Timetrace.scanrate; % 1/sampling rate
Timetrace.sampling_rate = 1 / Timetrace.time_per_point;
Timetrace.runtime_counts = ceil(Timetrace.sampling_rate * Timetrace.runtime);
Set_Processdelay(2, Timetrace.process_delay);

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

%% set realtime filering parameters

if MODE == 1

    cutoff = 1;
    order = 4;

    [b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');
    
    %subtracts the shift induced by averaging
    q = 1:3*wave_vec_length;
    q = q - round(Settings.clockfrequency/(Processdelay6 * Timetrace.sampling_rate * 2)); % q - (fsett/fmeasure)/2
    internal_reference_wave =  sqrt(2) * sin(q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing

    Set_Par(28, round(wave_vec_length/4));
    Set_Par(29, order);
    SetData_Double(3, [b, a], 0); %set filter parameters
    SetData_Double(4, internal_reference_wave, 0); %defines normalized reference for mixing, multiple length to simplify cosine in ADBASIC
    SetData_Double(2, [0, 0, 0, 0], 0); %sets the first 4 entries of DATA_2 to 0 for filtering purposes
    SetData_Double(5, [0, 0, 0, 0], 0); %sets the first 4 entries of DATA_5 to 0 for filtering purposes
    SetData_Double(6, [0, 0, 0, 0], 0); %sets the first 4 entries of DATA_6 to 0 for filtering purposes
    SetData_Double(7, [0, 0, 0, 0], 0); %sets the first 4 entries of DATA_7 to 0 for filtering purposes


end

%% run timetrace
Start_Process(2);
Timetrace.index = 1;
%% get current and show plot
Settings.N_ADC = 1;

Timetrace = Realtime_timetrace(Settings, Timetrace, Settings.type);

%% realtime filtering ADWIN readout and plot
if MODE == 1
    
    filtered_signal_inphase = GetData_Double(6, 4, Timetrace.sampling_rate * Timetrace.runtime);
    filtered_signal_quadrature = GetData_Double(5, 4, Timetrace.sampling_rate * Timetrace.runtime);
    R = sqrt(filtered_signal_inphase.^2 + filtered_signal_quadrature.^2);
    Theta = atan(filtered_signal_quadrature ./filtered_signal_inphase);

    hold on
    figure
    %plot(filtered_signal_quadrature, Color='r');
    plot(R, Color='r');
    figure
    %plot(filtered_signal_quadrature, Color='r')
    plot(Theta, Color='r');
    hold off

end


%% offline filtering
if MODE ==  0
    measured_signal = GetData_Double(2, 0, Timetrace.sampling_rate * Timetrace.runtime); %extracts input signal from Adwin

    %Idea: since sine is set at 50kHz but measured signal set at different frequency -> sine must be changed accordingly
    %calculates how many datapoints in measured_signal represent 1 period
    period_length = wave_vec_length * Timetrace.sampling_rate * Processdelay6 /Settings.clockfrequency;% Lvoltage * samplingrate/Voltagesettingfreq
    q = 1:length(measured_signal);%helper for sine multiplication

    timeshift = Get_Par(27); %shift of reference signal to measuring begin
    %initial_phase_shift = timeshift/wave_vec_length * 360;
    q = q + timeshift;

    %mixes measured_signal with a sine of same freq as our initial wave + the initial shift due to parallel implementation
    mixed_signal_inphase = measured_signal * Amplitude .* sin(q*2*pi/period_length + phi_shift*2*pi/360);
    mixed_signal_quadrature = measured_signal * Amplitude .* sin(q*2*pi/period_length + pi/2 + phi_shift*2*pi/360);

    % Lock-in calculations

    %filtered_signal_inphase = lowpass(mixed_signal_inphase,   1, Timetrace.sampling_rate); %non optimal, design filter yourself
    %filtered_signal_quadrature = lowpass(mixed_signal_quadrature, 1, Timetrace.sampling_rate); %non optimal, design filter yourself

    cutoff = 1;

    % Design a 4th-order Butterworth lowpass filter
    [b, a] = butter(4, cutoff / (Timetrace.sampling_rate / 2), 'low');

    % Apply the filter to remove high frequencies
    filtered_signal_inphase = filtfilt(b, a, mixed_signal_inphase);  % Zero-phase filtering
    filtered_signal_quadrature = filtfilt(b, a, mixed_signal_quadrature);

    R = sqrt(filtered_signal_inphase.^2 + filtered_signal_quadrature.^2);
    Theta = atan(filtered_signal_quadrature ./filtered_signal_inphase);

    %% plotting

    figure;
    hold on
    X =abs(fft(measured_signal));
    Y =abs(fft(mixed_signal_inphase));
    Z =abs(fft(filtered_signal_inphase));
    %plot(X(1:75), LineStyle="-", Color= 'w')
    %plot(Y(1:75), LineStyle='-', Color='b')
    %plot(Z(1:25), LineStyle='-', Color='r')
    hold off

    figure
    hold on
    %plot(mixed_signal_inphase)
    %plot(filtered_signal_inphase)
    plot(R)
    %plot(filtered_signal_quadrature)
    %plot(Theta(1:2*round(period_length)))
    %plot(R(1:2*round(period_length)))
    %plot(R)
    %plot(Theta)
    %plot(filtered_signal_inphase(1:15*period_length))
    %plot(mixed_signal_inphase(1:500))
    hold off
end







