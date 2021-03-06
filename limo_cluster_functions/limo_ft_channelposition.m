function [pnt, ori, lab] = limo_ft_channelposition(sens, varargin)

% CHANNELPOSITION
%
% Use either as
%   [pos]           = channelposition(sens, ...)
%   [pos, lab]      = channelposition(sens, ...)
%   [pos, ori, lab] = channelposition(sens, ...)

% Copyright (C) 2009, Robert Oostenveld & Vladimir Litvak
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: channelposition.m 952 2010-04-21 18:29:51Z roboos $
%
% renamed for integration in LIMO toolbox: GAR, University of Glasgow, June
% 2010

if isfield(sens, 'balance') && isfield(sens.balance, 'current') && ~strcmp(sens.balance.current, 'none')
  fnames = setdiff(fieldnames(sens.balance), 'current');
  indx   = find(ismember(fnames, sens.balance.current));

  if length(indx)==1,
    %  undo the synthetic gradient balancing
    fprintf('undoing the %s balancing\n', sens.balance.current);
    sens = apply_montage(sens, getfield(sens.balance, sens.balance.current), 'inverse', 'yes');
    sens.balance.current = 'none';
  else
    warning('cannot undo %s balancing\n', sens.balance.current);
  end
end

switch limo_ft_senstype(sens)
  case {'ctf151', 'ctf275' 'bti148', 'bti248', 'chieti153', 'yokogawa160'}
    % remove the non-MEG channels altogether
    sel = chantype(sens, 'meg');
    sens.label = sens.label(sel);
    sens.tra   = sens.tra(sel,:);

    % subsequently remove the unused coils
    used = any(abs(sens.tra)<0.5, 1);  % allow a little bit of rounding-off error
    sens.pnt = sens.pnt(used,:);
    sens.ori = sens.ori(used,:);
    sens.tra = sens.tra(:,used);

    % compute distances from the center
    dist = sqrt(sum((sens.pnt - repmat(mean(sens.pnt), size(sens.pnt, 1), 1)).^2, 2));

    % put the corresponding distances instead of non-zero tra entries
    dist = (abs(sens.tra)>0.5).*repmat(dist', size(sens.tra, 1), 1);

    % put nans instead of the zero entries
    dist(~dist) = inf;

    % use the matrix to find coils with minimal distance to the center, i.e. the bottom coil
    [junk, ind] = min(dist, [], 2);

    lab = sens.label;
    pnt = sens.pnt(ind, :);
    ori = sens.ori(ind, :);

  case {'ctf151_planar', 'ctf275_planar', 'bti148_planar', 'bti248_planar', 'chieti153_planar', 'yokogawa160_planar'}
    % create a list with planar channel names
    chan = {};
    for i=1:length(sens.label)
      if ~isempty(findstr(sens.label{i}, '_dH')) || ~isempty(findstr(sens.label{i}, '_dV'))
        chan{i} = sens.label{i}(1:(end-3));
      end
    end
    chan = unique(chan);
    % find the matching channel-duplets
    ind = [];
    lab = {};
    for i=1:length(chan)
      ch1 =  [chan{i} '_dH'];
      ch2 =  [chan{i} '_dV'];
      sel = match_str(sens.label, {ch1, ch2});
      if length(sel)==2
        ind = [ind; i];
        lab(i,:) = {ch1, ch2};
        meanpnt1 = mean(sens.pnt(abs(sens.tra(sel(1),:))>0.5, :), 1);
        meanpnt2 = mean(sens.pnt(abs(sens.tra(sel(2),:))>0.5, :), 1);
        pnt(i,:) = mean([meanpnt1; meanpnt2], 1);
      end
    end
    lab = lab(ind,:);
    pnt = pnt(ind,:);

  case 'neuromag122'
    % find the matching channel-duplets
    ind = [];
    lab = {};
    for i=1:2:140
      % first try MEG channel labels with a space
      ch1 = sprintf('MEG %03d', i);
      ch2 = sprintf('MEG %03d', i+1);
      sel = match_str(sens.label, {ch1, ch2});
      % then try MEG channel labels without a space
      if (length(sel)~=2)
        ch1 = sprintf('MEG%03d', i);
        ch2 = sprintf('MEG%03d', i+1);
        sel = match_str(sens.label, {ch1, ch2});
      end
      % then try to determine the channel locations
      if (length(sel)==2)
        ind = [ind; i];
        lab(i,:) = {ch1, ch2};
        meanpnt1 = mean(sens.pnt(abs(sens.tra(sel(1),:))>0.5,:), 1);
        meanpnt2 = mean(sens.pnt(abs(sens.tra(sel(2),:))>0.5,:), 1);
        pnt(i,:) = mean([meanpnt1; meanpnt2], 1);
      end
    end
    lab = lab(ind,:);
    pnt = pnt(ind,:);

  case 'neuromag306'
    % find the matching channel-triplets
    ind = [];
    lab = {};
    for i=1:300
      % first try MEG channel labels with a space
      ch1 = sprintf('MEG %03d1', i);
      ch2 = sprintf('MEG %03d2', i);
      ch3 = sprintf('MEG %03d3', i);
      sel = match_str(sens.label, {ch1, ch2, ch3});
      % the try MEG channels without a space
      if (length(sel)~=3)
        ch1 = sprintf('MEG%03d1', i);
        ch2 = sprintf('MEG%03d2', i);
        ch3 = sprintf('MEG%03d3', i);
        sel = match_str(sens.label, {ch1, ch2, ch3});
      end
      % then try to determine the channel locations
      if (length(sel)==3)
        ind = [ind; i];
        lab(i,:) = {ch1, ch2, ch3};
        meanpnt1 = mean(sens.pnt(abs(sens.tra(sel(1),:))>0.5,:), 1);
        meanpnt2 = mean(sens.pnt(abs(sens.tra(sel(2),:))>0.5,:), 1);
        meanpnt3 = mean(sens.pnt(abs(sens.tra(sel(3),:))>0.5,:), 1);
        pnt(i,:) = mean([meanpnt1; meanpnt2; meanpnt3], 1);
      end
    end
    lab = lab(ind,:);
    pnt = pnt(ind,:);


  otherwise
    % compute the position for each electrode

    if isfield(sens, 'tra')
      % each channel depends on multiple sensors (electrodes or coils)
      % compute a weighted position for the channel
      [nchan, ncoil] = size(sens.tra);
      pnt = zeros(nchan,3);
      for i=1:nchan
        weight = abs(sens.tra(i,:));
        weight = weight ./ norm(weight);
        pnt(i,:) = weight * sens.pnt;
      end
      lab = sens.label;

    else
      % there is one sensor per channel, which means that the channel position
      % is identical to the sensor position
      pnt = sens.pnt;
      lab = sens.label;
    end

end % switch senstype

n   = size(lab,2);
% this is to fix the planar layouts, which cannot be plotted anyway
if n>1 && size(lab, 1)>1 %this is to prevent confusion when lab happens to be a row array
  pnt = repmat(pnt, n, 1);
end

% ensure that it is a row vector
lab = lab(:);

% the function can be called with a different number of output arguments
if nargout==1
  pnt = pnt;
  ori = [];
  lab = [];
elseif nargout==2
  pnt = pnt;
  ori = lab;  % second output argument
  lab = [];   % third output argument
elseif nargout==3
  pnt = pnt;
  ori = ori;  % second output argument
  lab = lab;  % third output argument
end
