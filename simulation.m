%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Ruirong Chen - U pitt packet reconstruction simulation
%% Zigbee generation
%clearvars -except aaa
spc = 40;                            % samples per chip
msgLen = 8*60;                     % length in bits
message = repmat([0 0 1 1 0 0 0 1],1,20).';
waveform_zigbee = lrwpan.PHYGeneratorOQPSK(message, spc, '2450 MHz');
zigbee_spectrogram = fft(reshape(waveform_zigbee(1:6400),64,100),64);
MSK_signal = real(waveform_zigbee) +imag(waveform_zigbee);
figure(1)
subplot(2,1,1)
plot(real(waveform_zigbee));
subplot(2,1,2)
plot(imag(waveform_zigbee));

hMod = comm.MSKModulator('BitInput', true, ...
                    'InitialPhaseOffset', pi/2,'SamplesPerSymbol',20);
data = randi([0 1],300,1);
modSignal = step(hMod, data);
figure(20)
plot(real(modSignal));
figure(21)
plot(MSK_signal);
%%
cfgHT = wlanHTConfig;
cfgHT.ChannelBandwidth = 'CBW20'; % 20 MHz channel bandwidth
cfgHT.NumTransmitAntennas = 1;    % 2 transmit antennas
cfgHT.NumSpaceTimeStreams = 1;    % 2 space-time streams
cfgHT.PSDULength = 1000;          % PSDU length in bytes
cfgHT.MCS = 7;                   % 2 spatial streams, 64-QAM rate-5/6
cfgHT.ChannelCoding = 'BCC';      % BCC channel coding


tgnChannel = wlanTGnChannel;
tgnChannel.DelayProfile = 'Model-B';
tgnChannel.NumTransmitAntennas = cfgHT.NumTransmitAntennas;
tgnChannel.NumReceiveAntennas = 1;
tgnChannel.TransmitReceiveDistance = 10; % Distance in meters for NLOS
tgnChannel.LargeScaleFadingEffect = 'None';



snr = 5;


maxNumPEs = 10; % The maximum number of packet errors at an SNR point
maxNumPackets = 100; % Maximum number of packets at an SNR point

%%

qosDataCfg = wlanMACFrameConfig('FrameType', 'QoS Data');
disp(qosDataCfg);
% From DS flag
qosDataCfg.FromDS = 1;
% To DS flag
qosDataCfg.ToDS = 0;
% Acknowledgment Policy
qosDataCfg.AckPolicy = 'Normal Ack';
% Receiver address
qosDataCfg.Address1 = 'FCF8B0102001';
% Transmitter address
qosDataCfg.Address2 = 'FCF8B0102002';
payload = repmat('11', 1, 20);
qosDataFrame = wlanMACFrame(payload, qosDataCfg);
% Set the remaining variables for the simulation.

% Get the baseband sampling rate
fs = wlanSampleRate(cfgHT);

% Get the OFDM info
ofdmInfo = wlanHTOFDMInfo('HT-Data',cfgHT);

% Set the sampling rate of the channel
tgnChannel.SampleRate = fs;

% Indices for accessing each field within the time-domain packet
ind = wlanFieldIndices(cfgHT);


        
S = numel(snr);
packetErrorRate = zeros(S,1);
%parfor i = 1:S % Use 'parfor' to speed up the simulation
% Set random substream index per iteration to ensure that each
% iteration uses a repeatable set of random numbers
stream = RandStream('combRecursive','Seed',0);
stream.Substream = 1;
RandStream.setGlobalStream(stream);

% Create an instance of the AWGN channel per SNR point simulated
awgnChannel = comm.AWGNChannel;
awgnChannel.NoiseMethod = 'Signal to noise ratio (SNR)';
% Normalization
awgnChannel.SignalPower = 1/tgnChannel.NumReceiveAntennas;
% Account for energy in nulls
awgnChannel.SNR = snr(1)-10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones);

% Loop to simulate multiple packets
numPacketErrors = 0;
n = 1; % Index of packet transmitted

txPSDU = randi([0 1],cfgHT.PSDULength*8,1); % PSDULength in bytes
waveform_wifi = wlanWaveformGenerator(txPSDU,cfgHT);

% Add trailing zeros to allow for channel filter delay
waveform_wifi = [waveform_wifi; zeros(15,cfgHT.NumTransmitAntennas)]; 

% Pass the waveform through the TGn channel model 
reset(tgnChannel); % Reset channel for different realization

%rx = tgnChannel(tx);
mixed_waveform = waveform_zigbee + 5*[waveform_wifi;zeros(33300-3215,1)];

rx_mixed = awgnChannel(mixed_waveform);
%rx_mixed = awgnChannel(waveform_wifi);
% Add noise
rx = rx_mixed;

% Packet detect and determine coarse packet offset
coarsePktOffset = wlanPacketDetect(rx,cfgHT.ChannelBandwidth);

% Extract L-STF and perform coarse frequency offset correction
lstf = rx(coarsePktOffset+(ind.LSTF(1):ind.LSTF(2)),:); 
coarseFreqOff = wlanCoarseCFOEstimate(lstf,cfgHT.ChannelBandwidth);
rx = helperFrequencyOffset(rx,fs,-coarseFreqOff);

% Extract the non-HT fields and determine fine packet offset
nonhtfields = rx(coarsePktOffset+(ind.LSTF(1):ind.LSIG(2)),:); 
finePktOffset = wlanSymbolTimingEstimate(nonhtfields,...
    cfgHT.ChannelBandwidth);

% Determine final packet offset
pktOffset = coarsePktOffset+finePktOffset;

% If packet detected outwith the range of expected delays from the
% channel modeling; packet error


% Extract L-LTF and perform fine frequency offset correction
lltf = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:); 
fineFreqOff = wlanFineCFOEstimate(lltf,cfgHT.ChannelBandwidth);
rx = helperFrequencyOffset(rx,fs,-fineFreqOff);

% Extract HT-LTF samples from the waveform, demodulate and perform
% channel estimation
htltf = rx(pktOffset+(ind.HTLTF(1):ind.HTLTF(2)),:);
htltfDemod = wlanHTLTFDemodulate(htltf,cfgHT);
chanEst = wlanHTLTFChannelEstimate(htltfDemod,cfgHT);

% Extract HT Data samples from the waveform
htdata = rx(pktOffset+(ind.HTData(1):ind.HTData(2)),:);

% Estimate the noise power in HT data field
nVarHT = htNoiseEstimate(htdata,chanEst,cfgHT);
%,ofdmDemodData,qamDemodOut,scramInit,deintlvrOut,streamDeparserOut,qamDemodOut_hard]
% Recover the transmitted PSDU in HT Data
[rxPSDU,eqSYM] = wlanHTDataRecover(htdata,chanEst,nVarHT,cfgHT);
% qamDemodOut_HARD_ARRAY = reshape(qamDemodOut_hard, [], 1);
% deintlvrOut_HARD = wlanBCCDeinterleave(qamDemodOut_HARD_ARRAY, 'VHT', 208, 'CBW20');
% streamDeparserOut_HARD = wlanStreamDeparse(deintlvrOut_HARD, 1, 208, 4);
% decoded_hard = wlanBCCDecode(streamDeparserOut_HARD,0.75,'hard');
% encoded_reconstructed = wlanBCCEncode(decoded_hard,0.75);
% encoded_reconstructed_veri = wlanBCCDecode(encoded_reconstructed,0.75,'hard');
% 
% aaa1 = find(abs(double(encoded_reconstructed) - streamDeparserOut_HARD)==1);
% 
% isequal(encoded_reconstructed_veri,decoded_hard)

[Emulated_signal,scrambData,encodedData,interleavedData,streamParsedData,mappedData,packedData,rotatedData,dataCycShift,dataSpMapped]= wlanHTData_local(rxPSDU,cfgHT);

[Emulated_signal_TX,scrambData_Tx,encodedData_TX,interleavedData_TX,streamParsedData_TX,mappedData_TX,packedData_TX,rotatedData_TX,dataCycShift_TX,dataSpMapped_TX]= wlanHTData_local(txPSDU,cfgHT);

% Determine if any bits are in error, i.e. a packet error
bitError = biterr(txPSDU,rxPSDU);


Zigbee_rx     = lrwpan.PHYDecoderOQPSKNoSync(rx_mixed,  spc, '2450 MHz');
  [~, berOQPSK2450] = biterr(message, Zigbee_rx);
waveform_zigbee_reconstruct = lrwpan.PHYGeneratorOQPSK(Zigbee_rx, spc, '2450 MHz');

waveform_wifi_reconstruct = [wlanWaveformGenerator(rxPSDU,cfgHT); zeros(15,cfgHT.NumTransmitAntennas)];
  
WiFi_only_reconstruct = 5*[waveform_wifi_reconstruct;zeros(33300-3215,1)] - waveform_zigbee_reconstruct;  
rx_re = WiFi_only_reconstruct;
coarsePktOffset_re = wlanPacketDetect(rx_re,cfgHT.ChannelBandwidth);

% Extract L-STF and perform coarse frequency offset correction
lstf_re = rx(coarsePktOffset_re+(ind.LSTF(1):ind.LSTF(2)),:); 
coarseFreqOff_re = wlanCoarseCFOEstimate(lstf,cfgHT.ChannelBandwidth);
rx_re = helperFrequencyOffset(rx_re,fs,-coarseFreqOff_re);

% Extract the non-HT fields and determine fine packet offset
nonhtfields_re = rx(coarsePktOffset_re+(ind.LSTF(1):ind.LSIG(2)),:); 
finePktOffset_re = wlanSymbolTimingEstimate(nonhtfields_re,...
    cfgHT.ChannelBandwidth);

% Determine final packet offset
pktOffset_re = coarsePktOffset_re+finePktOffset_re;

% If packet detected outwith the range of expected delays from the
% channel modeling; packet error


% Extract L-LTF and perform fine frequency offset correction
lltf_re = rx_re(pktOffset_re+(ind.LLTF(1):ind.LLTF(2)),:); 
fineFreqOff_re = wlanFineCFOEstimate(lltf_re,cfgHT.ChannelBandwidth);
rx_re = helperFrequencyOffset(rx_re,fs,-fineFreqOff_re);

% Extract HT-LTF samples from the waveform, demodulate and perform
% channel estimation
htltf_re = rx_re(pktOffset+(ind.HTLTF(1):ind.HTLTF(2)),:);
htltfDemod_re = wlanHTLTFDemodulate(htltf_re,cfgHT);
chanEst_re = wlanHTLTFChannelEstimate(htltfDemod_re,cfgHT);

% Extract HT Data samples from the waveform
htdata_re = rx(pktOffset_re+(ind.HTData(1):ind.HTData(2)),:);

% Estimate the noise power in HT data field
nVarHT_re = htNoiseEstimate(htdata_re,chanEst,cfgHT);

% Recover the transmitted PSDU in HT Data
[rxPSDU_re,eqSYM_re] = wlanHTDataRecover(htdata_re,chanEst_re,nVarHT_re,cfgHT);  

bitError_re = biterr(txPSDU,rxPSDU_re);





figure(2)
plot(real(waveform_wifi));

figure(3)
plot(real(rx_mixed));
