function [value,coverage,window] = gaMaximumPlateau(y,tMin,s0,s1,duration)
% Maximum arithmetic mean of complete, frame-aligned windows (Automatic SCM).
value=NaN; coverage=0; window=[NaN NaN];
y=double(y(:)'); tMin=double(tMin(:)');
if numel(y)~=numel(tMin)||numel(y)<2||any(~isfinite(tMin))|| ...
        any(diff(tMin)<=0)||~all(isfinite([s0 s1 duration]))||duration<=0||s1<=s0
    return;
end
dt=median(diff(tMin));
% TXT minute columns historically use six decimals. Their rounding jitter is
% not a missing frame, and must not reject an otherwise complete plateau.
tol=max(2e-6,16*eps(max(1,max(abs(tMin)))));
fittedStep=(tMin(end)-tMin(1))/(numel(tMin)-1);
if all(abs(diff(tMin)-fittedStep)<=tol), dt=fittedStep; end
tol=max(tol,dt*1e-6);
if duration>s1-s0+tol, return; end
if abs(duration-(s1-s0))<=tol
    idx=plateauIntervalFrames(tMin,[s0 s1],tol);
    if isempty(idx), return; end
    coverage=sum(isfinite(y(idx)))/numel(idx);
    if coverage==1, value=mean(y(idx)); window=tMin(idx([1 end])); end
    return;
end
width=ceil((duration-tol)/dt)+1;
width=max(2,width);
best=-Inf;
for k=find(tMin>=s0-tol & tMin<=s1-duration+tol)
    j=k+width-1;
    if j>numel(y)||tMin(j)>s1+tol|| ...
            any(abs(diff(tMin(k:j))-dt)>tol)|| ...
            abs(tMin(j)-tMin(k)-(width-1)*dt)>tol, continue; end
    v=y(k:j); coverage=max(coverage,sum(isfinite(v))/width);
    if any(~isfinite(v)), continue; end
    m=mean(v);
    if m>best, best=m; window=tMin([k j]); end
end
if isfinite(best), value=best; end
end
