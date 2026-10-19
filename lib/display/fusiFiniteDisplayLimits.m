function limits=fusiFiniteDisplayLimits(A)
% Bounded deterministic 1-99% display limits. Never modifies the signal.
n=numel(A);stride=max(1,ceil(n/1e6));v=double(A(1:stride:end));v=v(isfinite(v));
if isempty(v),limits=[0 1];return;end
limits=prctile(v,[1 99]);
if limits(2)<=limits(1),limits=[min(v) max(v)];end
if limits(2)<=limits(1),limits=limits(1)+[-.5 .5]*max(1,abs(limits(1))*eps*4);end
end
