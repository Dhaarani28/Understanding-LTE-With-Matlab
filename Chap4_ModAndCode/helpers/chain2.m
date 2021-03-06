% chain2 - Simple communication system for bit error rate evaluation.
%
% The communication system consists of:
%   - Scrambling
%   - Modulation
%   - AWGN channel
%   - Demodulation
%   - Descrambling
%
% The modulation scheme can be one of:
%   - QPSK
%   - 16QAM
%   - 64QAM
%
% Each modulation scheme can use one of the following demodulation methods:
%   - Hard-decision demodulation
%   - Soft-decision demodulation
%
% Usage:
%   [ber, nBits] = chain2(args)
%
% Input:
%   args: structure with the following elements:
%           args.EbNo:      desired Eb/N0 value in dB
%           args.maxErrs:   number of bit errors after which to stop simulation
%           args.maxBits:   number of sent bits after which to stop simulation
%           args.modScheme:    modulation modScheme, 'QPSK'|'16QAM'|'64QAM'
%           args.demodType: demodulation method, 'hard'|'soft'
%
% Output:
%   ber:   the total bit error rate of the entire simulation
%   nBits: the total number of transmitted bits during the simulation
%
% Understanding LTE with Matlab, Chap. 04 Ex. 02

% Daniel Weibel <danielmartin.weibel@polimi.it> July 2016
%------------------------------------------------------------------------------%

function [ber, nBits] = chain2(args)

% Arguments
EbNo      = args.EbNo;       % Scalar
maxErrs   = args.maxErrs;    % Scalar integer
maxBits   = args.maxBits;    % Scalar integer
modScheme    = args.modScheme;     % String
demodType = args.demodType;  % String

% Message size in bits
msgSize = 2400;
% Number of modulation symbols
switch modScheme
  case 'QPSK',  M = 4;
  case '16QAM', M = 16;
  case '64QAM', M = 64;
  otherwise
    error('Argument "modScheme" must be ''QPSK'', ''16QAM'', or ''64QAM''.');
end
% Number of bits per modulation symbol
k = log2(M); 
% Multiply EbNo (in dB) with k (number of bits per symbol). So we get the
% "energy per symbol"/No.
snr = EbNo + lin2db(k);
% If demodulation decision method is 'soft', estimate noise variance
switch demodType
  case 'hard'
  case 'soft'
    noiseVar = db2lin(-snr);
  otherwise
    error('Argument "demodType" must be ''hard'' or ''soft''.');
end

% Set up AWGN channel
persistent AWGNChannel
if isempty(AWGNChannel)
  AWGNChannel = comm.AWGNChannel;
end
AWGNChannel.EbNo = snr;

% Counters of number of bit errors and number of transmitted bits
nErrs = 0;
nBits = 0;

% Index of the current message, which influences the scrambling sequence
iSubframe = 0;

% Transmit messages until max. number of bit errors or max. numbrer of
% transmitted bits is reached.
while ((nErrs < maxErrs) && (nBits < maxBits))
  %----------------------------------------------------------------------------%
  % Transmitter
  %----------------------------------------------------------------------------%
  % Generate random bit string
  txBits = getBits(msgSize);
  % Scramble bit string with scrambling sequence
  txBitsScram = lteScramble(txBits, iSubframe);
  % Modulate scrambled bit string
  txSymb = lteModulate(txBitsScram, modScheme);

  %----------------------------------------------------------------------------%
  % Channel
  %----------------------------------------------------------------------------%
  rxSymb = AWGNChannel.step(txSymb);

  %----------------------------------------------------------------------------%
  % Receiver
  %----------------------------------------------------------------------------%
  switch demodType
    % Demodulation with hard-decision
    case 'hard'
      % Demodulate (to bit string)
      rxBitsScram = lteDemodulate(rxSymb, modScheme, demodType);
      % Descramble bits with same scrambling sequence as scrambling was done
      rxBits = lteDescramble(rxBitsScram, iSubframe, demodType);

    % Demodulation with soft-decision
    case 'soft'
      % Demodulate to log-likelihood ratio vector (one LLR for each bit)
      llrScram = lteDemodulate(rxSymb, modScheme, demodType, noiseVar);
      % Descramble LLR vector
      llr = lteDescramble(llrScram, iSubframe, demodType);
      % Translate LLRs to bits (positive -> 0; negative -> 1, zero -> 0)
      rxBits = llr2bit(llr, 'PosTo0NegTo1');
  end

  % Determine number of bit errors and add to total
  nErrs = nErrs + sum(txBits ~= rxBits);
  nBits = nBits + msgSize;

  % Increment subframe index and wrap index around at 20
  iSubframe = mod(iSubframe+2, 20);
end

% Calculate total bit error rate
ber = nErrs/nBits;
