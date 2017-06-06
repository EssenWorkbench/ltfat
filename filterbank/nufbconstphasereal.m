function [c,newphase,usedmask,tgrad,fgrad]=filterbankconstphasereal(s,g,a,tfr,fc,varargin)
%% Old help -> CONSTRUCTPHASEREAL  Construct phase for DGTREAL
%   Usage:  c=constructphasereal(s,g,a,M);
%           c=constructphasereal(s,g,a,M,tol);
%           c=constructphasereal(c,g,a,M,tol,mask);
%           c=constructphasereal(c,g,a,M,tol,mask,usephase);
%           [c,newphase,usedmask,tgrad,fgrad] = constructphasereal(...);
%
%   Input parameters:
%         s        : Initial coefficients.
%         g        : Analysis Gabor window.
%         a        : Hop factor.
%         M        : Number of channels.
%         tol      : Relative tolerance.
%         mask     : Mask for selecting known phase.
%         usephase : Explicit known phase.
%   Output parameters:
%         c        : Coefficients with the constructed phase.
%         newphase : Just the (unwrapped) phase.
%         usedmask : Mask for selecting coefficients with the new phase.
%         tgrad    : Relative time phase derivative.
%         fgrad    : Relative frequency phase derivative.
%
%   `constructphasereal(s,g,a,M)` will construct a suitable phase for the 
%   positive valued coefficients *s*.
%
%   If *s* contains the absolute values of the Gabor coefficients of a signal
%   obtained using the window *g*, time-shift *a* and number of channels 
%   *M*, i.e.:
%
%     c=dgtreal(f,g,a,M);
%     s=abs(c);
%
%   then `constuctphasereal(s,g,a,M)` will attempt to reconstruct *c*.
%
%   The window *g* must be Gaussian, i.e. *g* must have the value `'gauss'`
%   or be a cell array `{'gauss',...}`.
%
%   `constructphasereal(s,g,a,M,tol)` does as above, but sets the phase of
%   coefficients less than *tol* to random values.
%   By default, *tol* has the value 1e-10. 
%
%   `constructphasereal(c,g,a,M,tol,mask)` accepts real or complex valued
%   *c* and real valued *mask* of the same size. Values in *mask* which can
%   be converted to logical true (anything other than 0) determine
%   coefficients with known phase which is used in the output. Only the
%   phase of remaining coefficients (for which mask==0) is computed.
%
%   `constructphasereal(c,g,a,M,tol,mask,usephase)` does the same as before
%   but uses the known phase values from *usephase* rather than from *c*.
%
%   In addition, *tol* can be a vector containing decreasing values. In 
%   that case, the algorithm is run `numel(tol)` times, initialized with
%   the result from the previous step in the 2nd and the further steps.
%
%   Further, the function accepts the following flags:
%
%      'freqinv'  The constructed phase complies with the frequency
%                 invariant phase convention such that it can be directly
%                 used in |idgtreal|.
%                 This is the default.
%
%      'timeinv'  The constructed phase complies with the time-invariant
%                 phase convention. The same flag must be used in the other
%                 functions e.g. |idgtreal|
%
%   This function requires a computational subroutine that is only
%   available in C. Use |ltfatmex| to compile it.
%
%   See also:  dgtreal, gabphasegrad, ltfatmex
%
%   References: ltfatnote040
%

% AUTHOR: Peter L. Søndergaard, Zdenek Prusa

thismfilename = upper(mfilename);
%complainif_notposint(a,'a',thismfilename);


definput.keyvals.tol=[1e-10,1e-10];
definput.keyvals.gderivweight=1/2;
definput.keyvals.mask=[];
definput.keyvals.usephase=[];
[flags,kv,tol,mask,usephase]=ltfatarghelper({'tol','mask','usephase'},definput,varargin);

% if ~isnumeric(s) 
%     error('%s: *s* must be numeric.',thismfilename);
% end
% 
% if ~isempty(usephase) && isempty(mask)
%     error('%s: Both mask and usephase must be used at the same time.',...
%           upper(mfilename));
% end
% 
% if isempty(mask) 
%     if ~isreal(s) || any(s(:)<0)
%         error('%s: *s* must be real and positive when no mask is used.',...
%               thismfilename);
%     end
% else 
%     if any(size(mask) ~= size(s)) || ~isreal(mask)
%         error(['%s: s and mask must have the same size and mask must',...
%                ' be real.'],thismfilename)
%     end
%     % Sanitize mask (anything other than 0 is true)
%     mask = cast(mask,'double');
%     mask(mask~=0) = 1;
% end
% 
% if ~isempty(usephase)
%     if any(size(mask) ~= size(s)) || ~isreal(usephase)
%         error(['%s: s and usephase must have the same size and usephase must',...
%                ' be real.'],thismfilename)        
%     end
% else
%     usephase = angle(s);
% end

% 
% if ~isnumeric(tol) || ~isequal(tol,sort(tol,'descend'))
%     error(['%s: *tol* must be a scalar or a vector sorted in a ',...
%            'descending manner.'],thismfilename);
% end


M = numel(s);

N = cellfun(@(sEl) size(sEl,1),s);
W = size(s{1},2);

usephase = arrayfun(@(NEl) zeros(NEl,W),N,'UniformOutput',0);
mask = [];%cellfun(@(NEl) ones(NEl,W),N,'UniformOutput',0);

asan = comp_filterbank_a(a,M);
a = asan(:,1)./asan(:,2);

L=N(1)*a(1);

tic
NEIGH = comp_nufbneighbors(a,numel(s),N);
chanStart = [0;cumsum(N)];
toc

 posInfo = zeros(chanStart(end),2);
 for kk = 1:M
    posInfo(chanStart(kk)+(1:N(kk)),:) = [(kk-1)*ones(N(kk),1),(0:N(kk)-1)'.*a(kk)];
 end
 posInfo = posInfo.';

% Prepare differences of center frequencies [given in normalized frequency]
% and dilation factors (square root of the time-frequency ratio)
%cfreqdiff = [diff(fc)];
%sqtfr = sqrt(tfr);
%sqtfrdiff = diff(sqtfr);

% Filterbankphasegrad does not support phasederivatives from absolute
% values

s = cell2mat(s);
abss = abs(s);

% difforder = 2;
% tt=-11;
% 
% logs = log(abss + realmin);
% logsMax = max(logs);
% logs(logs<logsMax+tt) = tt;
% 
% % Obtain the (relative) phase difference in frequency direction by taking
% % the time derivative of the log magnitude and weighting it by the
% % time-frequency ratio of the appropriate filter.
% % ! Note: This disregards the 'quadratic' factor in the equation for the 
% % phase derivative !
% 
% tmagdiff = zeros(size(logs));
% fgrad = zeros(size(logs));
% for kk = 1:M
%     idx = chanStart(kk)+1:chanStart(kk)+N(kk);
%     tmagdiff(idx) = pderiv(logs(idx),1,difforder);
%     fgrad(idx) = tmagdiff(idx).*tfr(kk)/(2*pi);
%     
%     tmagdiff(idx) = tmagdiff(idx)/N(kk);
% end
% 
% %tmagdiff2 = cell2mat(tmagdiff);
% 
% % Obtain the (relative) phase difference in time direction using the
% % frequency derivative of the log magnitude. The result is the mean of
% % estimates obtained from 'above' and 'below', appropriately weighted by
% % the channel distance and the inverse time-frequency ratio of the
% % appropriate filter.
% % ! Note: We consider the term depending on the time-frequency ratio 
% % difference, but again disregard the 'quadratic' factor. !
% %fac = 0;
% %fac = 1/2; 
% %fac = 2/3;
% %fac = 2/pi;
% 

% 
% fac = kv.gderivweight;
% %tgrad = cell(numel(s),1);
% tgrad = zeros(size(abss));
% 
% for kk = 1:M    
%     temp = zeros(N(kk),2);    
%     for ll = 1:N(kk) 
%         w = chanStart(kk) + ll;
%         tempVal = 0;
%         numNeigh = 0;
%         for jj = 1:2
%            neigh = NEIGH(4+jj,w);           
%            if neigh
%               numNeigh = numNeigh+1;
%               dist = (posInfo(neigh,2)-posInfo(w,2))/a(kk);
%               tempVal = tempVal + (logs(neigh)-logs(w)...
%                      -dist*tmagdiff(w));
%            end
%         end
%         if numNeigh
%             temp(ll,1) = tempVal/numNeigh;
%         end
%         
%         tempVal = 0;
%         numNeigh = 0;
%         for jj = 1:2
%            neigh = NEIGH(2+jj,w);           
%            if neigh
%               numNeigh = numNeigh+1;
%               dist = (posInfo(neigh,2)-posInfo(w,2))/a(kk);
%               tempVal = tempVal + (logs(w)-logs(neigh)...
%                      -dist*tmagdiff(w));
%            end
%         end
%         
%         if numNeigh
%             temp(ll,2) = tempVal/numNeigh; 
%         end           
%     end
%     if kk~=M
%         temp(:,1) = (temp(:,1) + fac*sqtfrdiff(kk)./sqtfr(kk))./cfreqdiff(kk);
%     end
%     if kk~=1
%         temp(:,2) = (temp(:,2) + fac*sqtfrdiff(kk-1)./sqtfr(kk))./cfreqdiff(kk-1);
%     end
%     % Maybe a factor of 1/2 is missing here?
%     tgrad(chanStart(kk)+1:chanStart(kk)+N(kk)) = sum(temp,2)./tfr(kk)./(pi*L);
% end
NEIGH = NEIGH-1;
tic
[tgrad,fgrad,logs] = comp_nufbphasegrad(abss,N,a,M,sqrt(tfr),fc,NEIGH,posInfo,kv.gderivweight);
toc
tic
[newphase, usedmask] = comp_nufbconstphasereal(abss,tgrad,fgrad,N,NEIGH,posInfo,fc,a,M,tol,mask,usephase);
toc
% Build the coefficients
%usedmask = mat2cell(usedmask,N,W);

c = mat2cell(abss.*exp(1i*newphase),N,W);
newphase = mat2cell(newphase,N,W);

%c=cellfun(@(sEl,pEl) sEl.*exp(1i*pEl),abss,newphase,'UniformOutput',0);
end

