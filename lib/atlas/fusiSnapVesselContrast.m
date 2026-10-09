function profile=fusiSnapVesselContrast(volume)
% Display-only robust window and gamma for the already-aligned SNAP overlay.
% Curve coordinates are normalized to the complete image intensity range,
% as required by ITK-SNAP's DisplayMapping/Curve registry (not raw values).
values=double(volume(isfinite(volume)));
profile=struct('window',[0 1],'normalizedWindow',[0 1],'gamma',.65,'overlayOpacity',.95);
if isempty(values),return;end
limits=[min(values) max(values)];
if limits(2)<=limits(1),return;end
positive=values(values>max(0,limits(1)));
if numel(positive)<2,return;end
if numel(positive)>200000,positive=positive(round(linspace(1,numel(positive),200000)));end
window=prctile(positive,[5 98.5]);
if window(2)<=window(1),window=limits;end
profile.window=window;
profile.normalizedWindow=(window-limits(1))/diff(limits);
end
