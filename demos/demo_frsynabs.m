%DEMO_FRSYNABS  Contruction of a signal with a given spectrogram
%
%   This demo demonstrates iterative reconstruction of a spectrogram.
%
%   .. figure::
%
%      Original spectrogram
%
%      This figure shows the target spectrogram
%
%   .. figure::
%
%      Linear reconstruction
%
%      This figure shows a spectrogram of a linear reconstruction of the
%      target spectrogram.
%
%   .. figure::
%
%      Iterative reconstruction using the Griffin-Lim method.
%
%      This figure shows a spectrogram of an iterative reconstruction of the
%      target spectrogram using the Griffin-Lim projection method.
%
%   .. figure::
%
%      Iterative reconstruction using the BFGS method
%
%      This figure shows a spectrogram of an iterative reconstruction of the
%      target spectrogram using the BFGS method.
%
%   See also:  isgramreal, isgram, 

s=ltfattext;

figure(1);
imagesc(s);
colormap(gray);
axis('xy');

figure(2);
F = frame('dgtreal','gauss',8,800); 
scoef = framenative2coef(F,s);
sig_lin = frsyn(F,sqrt(scoef));
sgram(sig_lin,'dynrange',100);

figure(3);
sig_griflim = frsynabs(F,scoef);
sgram(sig_griflim,'dynrange',100);

figure(4);
sig_bfgs = frsynabs(F,scoef,'bfgs');
sgram(sig_bfgs,'dynrange',100);
