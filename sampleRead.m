
%Copyright (C) 2014  Timo Rantalainen tjrantal at gmail dot com
%
%   This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%A sample to use the catapultRawReader function
%
clear all;
close all;
fclose all;
clc;

addpath('functions');	%/*Add catapultRawReader function*/
%Paths to sample files to read
filePath = 'sampleData\{None} 9326 201402051224.raw';
filePath2 = 'sampleData\{None} 9326 201402051224.csv';
%Read the data from the .raw file
data = catapultRawReader(filePath);
%Data read -> compare against exported data
%Read the data from the csv file
tempData = dlmread(filePath2,',',8,1);	%8 header rows, first column of time given in 00:00:00 format, which cannot be read with dlmread...
%Accelerometer data
csvData.channels{4} = -tempData(:,1);
csvData.channels{3} = tempData(:,2);
csvData.channels{2} = tempData(:,3);
%Gyroscope data
csvData.channels{7} = -tempData(:,4);
csvData.channels{5} = tempData(:,5);
csvData.channels{6} = tempData(:,6);
%Magnetometer data
csvData.channels{10} = -tempData(:,7);
csvData.channels{8} = tempData(:,8);
csvData.channels{9} = tempData(:,9);

%Check how well the scaling matches
fh = figure('position',[10 10 1500 800]);
for i = 2:length(data.channels)	
	A = [repmat(1,length(data.channels{i}),1) data.channels{i}];
	B = csvData.channels{i};
	coefficient = A\B;
	subplot(3,3,i-1);
	plot(csvData.channels{i},'r');
	hold on;
	plot(data.channels{i}*coefficient(2)+coefficient(1),'k')
	title(['data.channels{' num2str(i) '} intercept ' num2str(coefficient(1)) ' slope ' num2str(coefficient(2))])
end
fh = figure('position',[10 10 1500 800]);
for i = 2:length(data.channels)
	subplot(3,3,i-1)
	plot(data.channels{i},'k');		%Data from the .raw -file
	hold on;
	plot(csvData.channels{i},'r');	%Data from the CSV -file
	title(['data.channels {' num2str(i) '}'])
end
