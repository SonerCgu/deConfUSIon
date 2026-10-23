function limits=fusiAtlasIntensityLimits(image)
% Stable window across slices; zeros outside reference coverage stay black.
step=max(1,ceil(numel(image)/500000));values=double(image(1:step:end));
values=values(isfinite(values)&values>0);
if isempty(values),limits=[0 1];return;end
limits=quantile(values,[.005 .995]);
if limits(2)<=limits(1),limits=[0 max(values)];end
if limits(2)<=limits(1),limits=[0 1];end
end
