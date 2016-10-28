function H = freqwin(name,L,bw,varargin)
%FREQWIN 
%
%   `freqwin(name,L,bw)` returns a frequency window *name* of length *L* 
%   with the mainlobe -6dB bandwidth *bw*. It is intended to represent a
%   frequency response of a band-pass filter/window with bandwidth *bw*.
%   The bandwidth is given in normalised frequencies.
%
%   The function is not periodically wrapped should it be nonzero outside
%   of the *L* samples (as opposed to e.g. |pgauss|).
%
%   The following windows can be used in place of *name*:
%
%     'gauss'
%         Gaussian window
%
%     'gammatone' or {'gammatone',order}
%         Gammatone window of order *order*. The default order is 4.
%
%     'butterworth' or {'butterworth',order}
%
%     'roex'
%         
%   `freqwin` understands the following key-value pairs and flags at the end of 
%   the list of input parameters:
%
%     'fs',fs      If the sampling frequency *fs* is specified then the *bw*
%                  is expected to be on Hz.
%
%     'shift',s    Shift the window by $s$ samples. The value can be a
%                  fractional number.   
%
%     'wp'         Output is whole point even. This is the default. It
%                  corresponds to a shift of $s=0$.
%
%     'hp'         Output is half point even, as most Matlab filter
%                  routines. This corresponds to a shift of $s=-.5$
%
%   Additionally, the function accepts flags to normalize the output. Please see
%   the help of |normalize|. Default is to use `'peak'` normalization.
%
%   Examples
%   --------
%
%   
%
%   See also: firwin, plotfft

% AUTHORS: Nicki Holighaus

complainif_notenoughargs(nargin,3,upper(mfilename));

if ~isscalar(L)
    error('%s: L must be a scalar',upper(mfilename));
end

if ~isscalar(bw)
    error('%s: bw must be a scalar',upper(mfilename));
end

freqwintypes = arg_freqwin(struct);
freqwintypes = freqwintypes.flags.wintype;

if ~iscell(name), name = {name}; end

if ~ischar(name{1}) || ~any(strcmpi(name{1},freqwintypes))
  error('%s: First input argument must the name of a supported window.',...
        upper(mfilename));
end;

winArgs = name(2:end);
winName = lower(name{1});

definput.import={'normalize'};
definput.importdefaults={'null'};
definput.flags.centering={'wp','hp','shift'};
definput.keyvals.shift = 0;
definput.keyvals.fs = 2;
definput.keyvals.atheight = 10^(-3/10);
[flags,kv,fs]=ltfatarghelper({'fs'},definput,varargin);

if flags.do_wp
  kv.shift=0;
end;

if flags.do_hp
  kv.shift=0.5;
end;

if ( kv.shift >= .5 || kv.shift < -.5 )
    error('%s: Parameter shift must be in ]-.5,.5].',upper(mfilename));
end

if ( bw > fs || bw < eps )
     error('%s: Parameter bw must be in ]0,fs].',upper(mfilename));
end

step = fs/L; 
bwrelheight = kv.atheight;
H = (-kv.shift+[0:1:ceil(L/2)-1,-floor(L/2):-1]');

switch winName
    case 'gauss'
        H = exp(4*H.^2*log(bwrelheight)/(bw/step)^2);
    
    case 'butterworth'
        definputbutter.keyvals.order=4;
        [~,~,order]=ltfatarghelper({'order'},definputbutter,winArgs);
        H = 1./(sqrt(1 + (H/(bw/step/2)).^(2*order)));
        
     case 'chebyschevI'
         definputchebyI.keyvals.ripplefac = 0.01;
         [~,~,ripplefac]=ltfatarghelper({'ripplefac'},definputchebyI,winArgs);
         

    case 'gammatone'
        definputgamma.keyvals.order=4;
        [~,~,order]=ltfatarghelper({'order'},definputgamma,winArgs);

        gtInverse = @(yn) sqrt(yn^(-2/order)-1);
        dilation = bw/2/gtInverse(bwrelheight)/step;
        H = (1+1i*abs(H)/dilation).^(-order);
    otherwise 
        error('%s: SENTINEL. Unknown window.',upper(mfilename));
end

H=normalize(H,flags.norm);
