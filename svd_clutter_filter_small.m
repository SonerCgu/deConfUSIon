function I_filtered = svd_clutter_filter_small(I, rejectPercent)
% Minimal educational SVD clutter filter. Time must be the last dimension.
% For large datasets use deConfUSIon_svd_clutter, which is chunked and safer.
if nargin < 2, rejectPercent = 20; end
sz = size(I); T = sz(end);
X = reshape(double(I),[],T);
C = X' * X;
[V,D] = eig((C+C')/2,'vector');
[~,ord] = sort(real(D),'descend'); V = V(:,ord);
k = max(0,min(T-1,round(T*rejectPercent/100)));
if k > 0
    X = X - (X*V(:,1:k))*V(:,1:k)';
end
I_filtered = reshape(single(X),sz);
end
