function profile=fusiVolumeAutoAppearance(S)
% Deterministic baseline-only display profile, stable over movie frames.
if isfield(S,'autoAppearance'),profile=S.autoAppearance;return;end
signal=S.signal;valid=S.underlayValid & isfinite(signal);
values=signal(valid);cut=1;
if ~isempty(values)
    cut=max(.01,.2*graythresh(values));
end
power=S.underlay;power(~valid | signal<cut)=0;
% Match aggregate ray attenuation rather than assigning an opacity that
% changes with the number of sampled slices. Use all three grid directions.
paths=[reshape(sum(power,1),[],1);reshape(sum(power,2),[],1);reshape(sum(power,3),[],1)];
paths=sort(paths(paths>0 & isfinite(paths)));
opacity=.06;
if ~isempty(paths)
    typical=paths(max(1,round(.75*numel(paths))));
    opacity=min(.18,max(.02,-log(.60)/max(typical,eps)));
end
profile=struct('cutoff',double(cut),'opacity',double(opacity), ...
    'rule','Baseline only: 0.2 Otsu cutoff; bounded ray opacity targeting 40% attenuation at the 75th percentile path.');
end
