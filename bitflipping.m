%%%% simulation of bit flipping in encoder
% Ruirong Chen 
% University of Pittsburgh
%clear all
bits = randi([0 1],260,1);
encoded_bits = wlanBCCEncode(bits,'5/6');
interleaved_bits = wlanBCCInterleave(encoded_bits,'VHT',52*6,'CBW20');
error_bits = interleaved_bits;
randi_loc = sort(randi([1 312],20,1));
error_bits(31:72,1) = ~interleaved_bits(31:72,1);
error_bits(randi_loc,1) = ~interleaved_bits(randi_loc,1);
error_bits_deinterleave = wlanBCCDeinterleave(error_bits,'VHT',52*6,'CBW20');

error_bits_decode = wlanBCCDecode(error_bits_deinterleave,'5/6','hard');
error_bits_encode = wlanBCCEncode(error_bits_decode,'5/6');
error_bits_interleaved = wlanBCCInterleave(error_bits_encode,'VHT',52*6,'CBW20');
bit_difference = sum(abs(double(error_bits_decode) - double(bits)));
flip_bits = error_bits_interleaved;
flip_bits(31:72,1) = ~error_bits_interleaved(31:72,1);
flip_bits_deinterleave = wlanBCCInterleave(flip_bits,'VHT',52*6,'CBW20');
flip_bits_decode = wlanBCCDecode(flip_bits_deinterleave,'5/6','hard');
flip_bits_encode = wlanBCCEncode(flip_bits_decode,'5/6');

bit_difference_flip =  sum(abs(double(flip_bits) - double(error_bits)));
bit_difference_encode =  sum(abs(double(error_bits_encode) - double(error_bits)));
bit_different_loc5 = find(abs(double(error_bits_encode) - double(error_bits))==1);
bit_difference_flip_encode =  sum(abs(double(flip_bits_encode) - double(error_bits)));