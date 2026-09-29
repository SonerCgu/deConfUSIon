function [starts,width]=scmSearchWindows(w,duration,TR,T)
% Plateau windows are frame-aligned, fully inside the requested search range.
assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>w(1)&&w(2)<=T*TR, ...
    'deConfUSIon:ProtocolWindow','Search interval must lie inside the acquisition.');
assert(isscalar(duration)&&isfinite(duration)&&duration>=0, ...
    'deConfUSIon:PlateauWindow','Plateau duration must be nonnegative (0 = whole interval).');
if duration==0
    e=max(1,min(T,round(w/TR)+1)); starts=e(1); width=e(2)-e(1)+1; return;
end
% Include endpoints: ceil(duration/TR) sample intervals, at least requested duration.
width=ceil(duration/TR-1e-10)+1;
first=max(1,ceil(w(1)/TR-1e-10)+1); last=min(T,floor(w(2)/TR+1e-10)+1);
starts=first:(last-width+1);
assert(~isempty(starts),'deConfUSIon:PlateauWindow', ...
    'No complete plateau fits inside this range at the acquired frame rate. Shorten its duration or widen the range.');
end
