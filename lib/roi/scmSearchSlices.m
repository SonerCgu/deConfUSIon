function slices=scmSearchSlices(opt,nz)
% Resolve inclusive search bounds while retaining legacy all/current options.
if opt.allSlices
    bounds=[1 nz];
    if isfield(opt,'sliceRange'), bounds=opt.sliceRange; end
else
    bounds=[opt.slice opt.slice];
end
assert(isnumeric(bounds)&&isreal(bounds)&&numel(bounds)==2&& ...
    all(isfinite(bounds(:)))&&all(bounds(:)==round(bounds(:)))&& ...
    bounds(1)>=1&&bounds(2)<=nz&&bounds(1)<=bounds(2), ...
    'deConfUSIon:SearchSliceRange', ...
    'Slice start/end must be whole numbers from 1 to %d, with start <= end.',nz);
slices=bounds(1):bounds(2);
end
