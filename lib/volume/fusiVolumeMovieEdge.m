function edge=fusiVolumeMovieEdge(fig,displaySize)
edge=max(displaySize);h=findobj(fig,'Tag','VolumeMovieResolution');
if isempty(h),return;end
if startsWith(h.Value,'Fast'),edge=720;elseif startsWith(h.Value,'HD'),edge=1080;elseif startsWith(h.Value,'Full HD'),edge=1920;end
end
