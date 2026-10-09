function profile=scmAutomaticDisplay(A,candidates,opt,maskForSlice)
% Display-only scaling; never fed back into ROI scoring or exported traces.
% One profile for the entire animal, across all selected slices/windows.
values=cell(1,numel(candidates));
for k=1:numel(candidates)
    c=candidates{k};
    regions=scmSearchRegions(opt,c.slice,maskForSlice(c.slice));
    mask=false(size(A,1),size(A,2));
    for r=1:numel(regions), mask=mask|regions(r).mask; end
    s=average(c.signalFrames,c.slice);
    if isfield(c,'baselineMode')&&strcmp(c.baselineMode,'external'),b=zeros(size(s));
    else,b=average(c.baselineFrames,c.slice);end
    m=100*(s-b)./(100+b);
    valid=mask & isfinite(m) & isfinite(b) & (100+b)>sqrt(eps('single'));
    values{k}=abs(m(valid));
end
v=vertcat(values{:});v=v(isfinite(v));
if isempty(v), error('deConfUSIon:DisplayRange','No finite samples available for automatic display scaling.'); end
upper=prctile(v,99);
% A silent/all-zero map still needs a usable color axis and alpha ramp.
upper=max(1,upper);
profile=struct('caxis',[0 upper],'modMin',upper/6,'modMax',upper/3,'alphaPercent',100, ...
    'mode','adaptive','rule','99th percentile of absolute, unsmoothed rebased SCM in the selected search area/windows; minimum range 1%; alpha ramp from 1/6 to 1/3 of upper limit', ...
    'sampleCount',numel(v),'scope','one animal; shared across selected slices and ROIs');
    function m=average(frames,z)
        m=zeros(size(A,1),size(A,2));
        for frame=frames
            if ndims(A)==3, m=m+double(A(:,:,frame));
            else, m=m+double(A(:,:,z,frame)); end
        end
        m=m/numel(frames);
    end
end
