%%%% simulation of bit flipping in encoder
% Ruirong Chen 
% University of Pittsburgh
%clear all
bit_length = 260;
num_sym = 2;
bits = randi([0 1],bit_length*num_sym,1);
overlapped_bit_loc=[];
for i = 1:num_sym
    overlapped_bit_loc = [overlapped_bit_loc 31+bit_length*(i-1)*6/5:72+bit_length*(i-1)*6/5];
end
encoded_bits = wlanBCCEncode(bits,'5/6');
interleaved_bits = wlanBCCInterleave(encoded_bits,'VHT',52*6,'CBW20');
error_bits = interleaved_bits;
randi_loc = sort(randi([1 bit_length*6/5],20,1));
randi_loc_overlapped = sort(randi([1 length(overlapped_bit_loc)],20,1));
error_bits(overlapped_bit_loc(randi_loc_overlapped),1) = ~interleaved_bits(overlapped_bit_loc(randi_loc_overlapped),1);
%error_bits(randi_loc,1) = ~interleaved_bits(randi_loc,1);
error_bits_deinterleave = wlanBCCDeinterleave(error_bits,'VHT',52*6,'CBW20');

error_bits_decode = wlanBCCDecode(error_bits_deinterleave,'5/6','hard');
error_bits_encode = wlanBCCEncode(error_bits_decode,'5/6');
error_bits_interleaved = wlanBCCInterleave(error_bits_encode,'VHT',52*6,'CBW20');
bit_difference = sum(abs(double(error_bits_decode) - double(bits)));
flip_bits = error_bits_interleaved;
flip_bits(overlapped_bit_loc,1) = ~error_bits_interleaved(overlapped_bit_loc,1);
flip_bits_deinterleave = wlanBCCInterleave(flip_bits,'VHT',52*6,'CBW20');
flip_bits_decode = wlanBCCDecode(flip_bits_deinterleave,'5/6','hard');
flip_bits_encode = wlanBCCEncode(flip_bits_decode,'5/6');

bit_difference_flip =  sum(abs(double(flip_bits) - double(error_bits)));
bit_difference_encode =  sum(abs(double(error_bits_encode) - double(error_bits)));
bit_different_loc5 = find(abs(double(error_bits_encode) - double(error_bits))==1);
bit_difference_flip_encode =  sum(abs(double(flip_bits_encode) - double(error_bits)));
