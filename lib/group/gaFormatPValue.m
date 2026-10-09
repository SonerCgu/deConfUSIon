function label=gaFormatPValue(p)
% Journal display: three decimal places; never modify the numeric test.
if ~isscalar(p)||~isfinite(p)||p<0||p>1, label='p = not available';return;end
if p<.001, label='p < 0.001';return;end
number=sprintf('%.3f',p);
% Avoid printing p=0.05 alongside a significant star after rounding.
for boundary=[.001 .01 .05]
    if str2double(number)==boundary && p~=boundary
        relation='>';if p<boundary,relation='<';end
        label=sprintf('p %s %.3f',relation,boundary);return;
    end
end
label=['p = ' number];
end
