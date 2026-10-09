function idx=plateauIntervalFrames(t,w,timestampTolerance)
% Samples inside a nominal full-search plateau; never extend its boundaries.
% A scan of N regularly sampled frames covers N*dt, although its last sample
% is at (N-1)*dt. Permit that final acquisition bin, but not a missing tail.
idx=[]; t=double(t(:)'); w=double(w(:)');
if numel(t)<2||numel(w)~=2||any(~isfinite(t))||any(diff(t)<=0)|| ...
        any(~isfinite(w))||w(2)<=w(1), return; end
dt=median(diff(t)); tol=max(1e-9,dt*1e-6);
if nargin>=3,tol=max(tol,timestampTolerance);end
if w(1)<t(1)-tol||w(2)>t(end)+dt+tol, return; end
candidate=find(t>=w(1)-tol & t<=w(2)+tol);
if numel(candidate)<2||any(abs(diff(t(candidate))-dt)>tol), return; end
idx=candidate;
end
