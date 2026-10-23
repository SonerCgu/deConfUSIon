function label=gaFormatPValue(p)
% Use three decimals normally, with extra precision near star thresholds.
% Never turn a rounded value into the criterion for the numeric test.
if ~isscalar(p)||~isfinite(p)||p<0||p>1, label='p = not available';return;end
if p<.001, label='p < 0.001';return;end
number=sprintf('%.3f',p);
% For example, 0.0013 must read p = 0.0013 beside **, not p = 0.001.
% Increase precision until rounding preserves the side of every threshold.
for boundary=[.001 .01 .05]
    if str2double(number)==boundary && p~=boundary
        for precision=3:17
            number=sprintf('%.*g',precision,p);
            displayed=str2double(number);
            if sign(displayed-boundary)==sign(p-boundary),break;end
        end
        break;
    end
end
label=['p = ' number];
end
