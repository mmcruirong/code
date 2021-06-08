%%%% simulation of bit flipping in encoder
% Ruirong Chen 
% University of Pittsburgh
%clear all
bits = randi([0 1],2400,1);
encoded_bits = wlanBCCEncode(bits,'1/2');
error_bits = encoded_bits;
randi_loc = sort(randi([1 240],20,1));
error_bits(80:7:2800,1) = ~encoded_bits(80:7:2800,1);
%error_bits(randi_loc,1) = ~encoded_bits(randi_loc,1);
error_bits_decode = wlanBCCDecode(error_bits,'1/2','hard');
error_bits_encode = wlanBCCEncode(error_bits_decode,'1/2');
bit_difference = sum(abs(double(error_bits_decode) - double(bits)));
flip_bits = error_bits_encode;
flip_bits(80:7:2800,1) = ~error_bits_encode(80:7:2800,1);
flip_bits_decode = wlanBCCDecode(flip_bits,'1/2','hard');
flip_bits_encode = wlanBCCEncode(flip_bits_decode,'1/2');

bit_difference_flip =  sum(abs(double(flip_bits) - double(error_bits)));
bit_difference_encode =  sum(abs(double(error_bits_encode) - double(error_bits)));
bit_different_loc5 = find(abs(double(error_bits_encode) - double(error_bits))==1);
bit_difference_flip_encode =  sum(abs(double(flip_bits_encode) - double(error_bits)));