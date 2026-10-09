function changed=fusiBaselineNeedsRecalculation(before,after)
% PSC depends on the mean map/window, not scan ordering or signal windows.
a=fusiBaselineReference('isExternal',before);b=fusiBaselineReference('isExternal',after);
changed=true;if a~=b,return;end
if a
    changed=~isequaln(before.reference.mean,after.reference.mean);
else
    changed=~isequaln([before.start before.end],[after.start after.end]);
end
end
