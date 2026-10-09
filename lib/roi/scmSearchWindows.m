function [starts,width]=scmSearchWindows(w,duration,TR,T)
% Sliding plateaus are frame-aligned. A plateau equal to the search duration
% has one candidate: all samples inside the requested interval.
assert(isscalar(TR)&&isfinite(TR)&&TR>0&&isscalar(T)&&isfinite(T)&&T>=2&&T==round(T), ...
    'deConfUSIon:ProtocolWindow','Acquisition needs a positive TR and at least two frames.');
w=double(w(:)'); tol=max(1e-9,TR*1e-6);
assert(numel(w)==2&&all(isfinite(w))&&w(1)>=-tol&&w(2)>w(1)&&w(2)<=T*TR+tol, ...
    'deConfUSIon:ProtocolWindow','Search interval must lie inside the acquisition.');
assert(isscalar(duration)&&isfinite(duration)&&duration>=0, ...
    'deConfUSIon:PlateauWindow','Plateau duration must be nonnegative (0 = whole interval).');
assert(duration<=diff(w)+tol,'deConfUSIon:PlateauWindow', ...
    'Plateau duration exceeds the search interval. Use a duration no longer than search end minus start.');
if duration==0
    e=max(1,min(T,round(w/TR)+1)); starts=e(1); width=e(2)-e(1)+1; return;
end
if abs(duration-diff(w))<=tol
    idx=plateauIntervalFrames((0:T-1)*TR,w);
    assert(~isempty(idx),'deConfUSIon:PlateauWindow', ...
        'The full search interval needs at least two acquired samples and must be covered by the recording.');
    starts=idx(1); width=numel(idx); return;
end
% Include endpoints: ceil(duration/TR) sample intervals, at least requested duration.
width=ceil(duration/TR-1e-10)+1;
first=max(1,ceil(w(1)/TR-1e-10)+1); last=min(T,floor(w(2)/TR+1e-10)+1);
starts=first:(last-width+1);
assert(~isempty(starts),'deConfUSIon:PlateauWindow', ...
    'No complete plateau fits inside this range at the acquired frame rate. Shorten its duration or widen the range.');
end
