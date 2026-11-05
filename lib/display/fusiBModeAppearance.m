function rgb=fusiBModeAppearance(rgb,appearance)
% Display-only window and tone for one mapped B-mode panel.
% With no arguments, return independent B-mode display defaults.
if nargin==0
 rgb=struct('brightness',0,'contrast',1,'gamma',1,'autoContrast',true);return;
end
if nargin<2,appearance=fusiBModeAppearance();end
rgb=single(rgb);valid=isfinite(rgb);rgb(~valid)=0;
values=rgb(valid);
if appearance.autoContrast&&~isempty(values)&&max(values)>min(values)
 limits=fusiFiniteDisplayLimits(values);
 rgb=(rgb-limits(1))/diff(limits);
end
rgb=min(1,max(0,rgb));
rgb=min(1,max(0,rgb*appearance.contrast+appearance.brightness));
rgb=rgb.^appearance.gamma;rgb(~valid)=0;
end
