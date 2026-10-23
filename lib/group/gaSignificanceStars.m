function stars=gaSignificanceStars(p)
% One convention for all test directions, previews and exports. Use the
% unrounded p-value; exact boundaries belong to the more significant tier.
if ~isscalar(p) || ~isfinite(p) || p<0 || p>1
    stars='p=?';
elseif p<=.001
    stars='***';
elseif p<=.01
    stars='**';
elseif p<=.05
    stars='*';
else
    stars='n.s.';
end
end
