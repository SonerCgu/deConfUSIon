function U=fusiStandardDopplerDisplay(power)
% Mask Editor's standard equalized-Doppler display preset, for one native
% coronal plane. Display only: never feed these pixels into quantitative PSC.
U=double(power);U(~isfinite(U) | U<0)=0;
if max(U(:))<=0,U=single(U);return;end
U=U/max(U(:));U=U-min(U(:));
U=U.*(1+(0:size(U,1)-1)'/size(U,1)*2);
U=U/max(U(:));m=median(U(:));
compression=1;if m>0 && m<1,compression=-1/log2(m);end
U=U.^compression;U=U/max(U(:));U=U-min(U(:));
U=min(1,max(0,(U-.4)/.4));U=min(1,max(0,U*.5+.1)).^(1/1.1);
amount=4.5*(1-exp(-75/60));sigma=1.1+.9*75/300;
hi=U-imgaussfilt(U,sigma,'Padding','replicate');
U=min(1,max(0,U+amount*.35.*tanh(hi/.35)));
gain=5;mid=.48;toe=.08;
curve=.5+.5*tanh(gain*(U-mid));lo=.5+.5*tanh(-gain*mid);
upper=.5+.5*tanh(gain*(1-mid));curve=(curve-lo)/(upper-lo);
curve=(1-toe)*curve+toe*sqrt(max(0,curve));
U=single(min(1,max(0,.6*U+.4*curve)));
U(power==0 | ~isfinite(power))=0;
end
