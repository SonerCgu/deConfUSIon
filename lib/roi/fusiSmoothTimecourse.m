function y=fusiSmoothTimecourse(xMinutes,y,windowSeconds)
% Centred sliding mean, in seconds; never smooth across scan breaks or NaNs.
assert(isscalar(windowSeconds)&&isfinite(windowSeconds)&&windowSeconds>0, ...
    'deConfUSIon:CurveSmoothWindow','Enter a positive smoothing window in seconds.');
valid=isfinite(xMinutes)&isfinite(y);edges=diff([false valid(:)' false]);
first=find(edges==1);last=find(edges==-1)-1;
for k=1:numel(first)
    take=first(k):last(k);if numel(take)<2,continue;end
    dt=median(diff(xMinutes(take)))*60;if ~isfinite(dt)||dt<=0,continue;end
    n=max(1,round(windowSeconds/dt));y(take)=movmean(y(take),n,'Endpoints','shrink');
end
end
