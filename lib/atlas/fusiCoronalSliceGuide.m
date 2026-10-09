function guide=fusiCoronalSliceGuide(spec,selected)
% Relative AP sampling guidance, not an anatomical bregma assignment.
q=double(spec.preparedPositions(:)');slices=double(spec.sourceSlices(:)');k=spec.current;
reference=spec.referenceAtlasIndex;if k==1,reference=selected;end
nominal=reference+q-q(1);
guide=struct('nominalAtlasIndices',nominal,'suggestedAtlasIndex',round(nominal(k)), ...
    'validForAccept',true,'scale',NaN,'warning','','atlasIntervals',diff(q));
guide.canEstimate=nominal(k)>=1 && nominal(k)<=spec.atlasCount;
guide.lines={sprintf('Scan slices %s: nominal atlas gaps %s intervals (%g / %g micrometres).', ...
    mat2str(slices),mat2str(abs(diff(q)),4),spec.scanSpacingUm,spec.atlasSpacingUm), ...
    sprintf('First scan at atlas %g gives nominal levels %s. Match anatomy; these are spacing estimates.',reference,mat2str(nominal,4))};
if k>1
    span=q(k)-q(1);mapped=selected-reference;guide.scale=mapped/span;
    guide.validForAccept=abs(guide.scale)>=.5 && abs(guide.scale)<=2;
    guide.lines{end+1}=sprintf('Current match: scan span %.3f mm -> atlas span %.3f mm; AP size factor %.3f.', ...
        abs(span)*spec.atlasSpacingUm/1000,abs(mapped)*spec.atlasSpacingUm/1000,abs(guide.scale));
    if ~guide.validForAccept
        guide.warning=sprintf('AP size factor %.3f is outside 0.5-2. Match a plane farther apart (nominal estimate %d), or check scan spacing and AP direction.',abs(guide.scale),guide.suggestedAtlasIndex);
    elseif guide.scale<0
        guide.warning='AP direction is reversed. After all three matches you will be asked whether to reverse the scan AP order.';
    elseif abs(guide.scale-1)>.2
        guide.warning='Atlas separation differs by more than 20% from nominal spacing. Verify anatomy and acquisition spacing.';
    end
else
    guide.lines{end+1}='This first match sets the AP reference. The following planes start at the expected physical separation.';
end
if ~isempty(guide.warning),guide.lines{end+1}=guide.warning;end
end
