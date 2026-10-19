function [flat, spikesPerFrame, spikeCounts] = fusiDespikeVoxels(flat, zthr, onProgress)
% Bounded MAD detection, retaining the original per-voxel interpolation.
% flat is the single-precision [voxel x time] working array used by despike.
if nargin < 3, onProgress = []; end
[nVox,T] = size(flat);
spikesPerFrame = zeros(1,T,'single');
spikeCounts = zeros(nVox,1,'single');
% Median/sorting and subtraction need several temporary copies. Keep their
% aggregate working set near 64 MiB rather than allocating another movie.
chunkV = max(1,floor(64*1024^2/(4*max(1,T)*4)));
x = 1:T;
for first = 1:chunkV:nVox
    last = min(nVox,first+chunkV-1);
    if isa(onProgress,'function_handle'), onProgress((first-1)/nVox); end
    block = flat(first:last,:);
    med = median(block,2);
    centered = bsxfun(@minus,block,med);
    madv = median(abs(centered),2);
    robustZ = bsxfun(@rdivide,0.6745*centered,madv);
    spikeMask = abs(robustZ) > zthr;
    spikeMask(madv < eps,:) = false;
    counts = sum(spikeMask,2);
    spikeCounts(first:last) = single(counts);
    spikesPerFrame = spikesPerFrame + single(sum(spikeMask,1));
    affected = find(counts > 0);
    for row = reshape(affected,1,[])
        bad = spikeMask(row,:);
        good = ~bad;
        if nnz(good) >= 2
            sig = block(row,:);
            sig(bad) = interp1(x(good),sig(good),x(bad),'linear','extrap');
            flat(first+row-1,:) = sig;
        end
    end
end
if isa(onProgress,'function_handle'), onProgress(1); end
end
