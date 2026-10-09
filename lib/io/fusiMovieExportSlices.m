function slices=fusiMovieExportSlices(selection,nSlices)
% Parse explicit slice numbers and inclusive ranges without evaluating code.
validateattributes(nSlices,{'numeric'},{'scalar','integer','positive'});
if isnumeric(selection)
    slices=double(selection(:)');
else
    tokens=regexp(strtrim(char(selection)),'[\s,;]+','split');slices=[];
    for k=1:numel(tokens)
        token=tokens{k};valid=regexp(token,'^\d+([:-]\d+)?$','once');
        assert(~isempty(valid),'deConfUSIon:MovieSlices','Enter slice numbers such as 1 2 10, or a range such as 1:10.');
        parts=regexp(token,'[:-]','split');first=str2double(parts{1});last=first;
        if numel(parts)>1,last=str2double(parts{2});end
        assert(first>=1&&last>=first&&last<=nSlices,'deConfUSIon:MovieSlices', ...
            'Choose slices between 1 and %d; range ends must be at least their start.',nSlices);
        slices=[slices first:last]; %#ok<AGROW>
    end
end
assert(~isempty(slices)&&isreal(slices)&&all(isfinite(slices))&& ...
    all(slices==round(slices))&&all(slices>=1&slices<=nSlices), ...
    'deConfUSIon:MovieSlices','Choose one or more whole-number slices between 1 and %d.',nSlices);
slices=unique(slices,'stable');
end
