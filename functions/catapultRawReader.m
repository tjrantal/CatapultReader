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

%Catapult raw file reader. Reverse engineered, so will not work for all catapult files
%Magnetometer scaling might be incorrect
%Cannot handle compressed files under any circumstance
%The sign of data differs between data read from raw files with this function and corresponding data exported with the Catapult Sprint software.
function data = catapultRawReader(fileIn)

	%Helper function to extract values from header strings
	function value = getHeaderValue(header,toLookFor,separator)
		counter = 1;
		while counter < length(header) && isempty(strfind(tolower(header(counter).string),tolower(toLookFor)))
			counter = counter+1;
		end
		if ~isempty(strfind(tolower(header(counter).string),tolower(toLookFor)))
			tempString = tolower(header(counter).string);
			valueStrings = strsplit(tempString,separator);
			value = valueStrings{2};
		else
			value = nan;
		end
	endfunction;

	%FILE READER BEGINS
	%String constants to extract data from the header
	%Gyroscope scaling coefficients. For some reasong DGyrZ0 - 2 do not add up.
	%gyroToLookFor = {'dgyrz0','dgyrg0','dgyrz1','dgyrg1','dgyrz2','dgyrg2'};
	gyroToLookFor = {'gyrozero1','gyrogain1','gyrozero2','gyrogain2','gyrozero0','gyrogain0'};
	%Accelerometer scaling coefficients.
	accToLookFor = {'DAcc+0','DAcc-0','DAcc+1','DAcc-1','DAcc+2','DAcc-2'};
	%Magnetometer scaling coefficients
	magToLookFor = {'DMag+0','DMag-0','DMag+1','DMag-1','DMag+2','DMag-2'};
	
	fh = fopen(fileIn,'rb');
	data = struct();
	%Read the header data
	data.headerData = char(fread(fh, 1024,'uint8'));
	fieldBeginnings = find(data.headerData == '$')+1;
	fieldEnds = find(data.headerData == ',')-1;
	data.header = struct();
	%Save the header data in strings
	for i = 1:length(fieldBeginnings)
		data.header(i).string = data.headerData(fieldBeginnings(i):fieldEnds(i))';
	end

	%Extract calibrations from the header
	for i = 1:length(gyroToLookFor)
		data.gyroCalib(i) = str2double(getHeaderValue(data.header,gyroToLookFor{i},'='));
	end


	for i = 1:length(accToLookFor)
		data.accCalib(i) = str2double(getHeaderValue(data.header,accToLookFor{i},'='));
	end

	for i = 1:length(magToLookFor)
		data.magCalib(i) = str2double(getHeaderValue(data.header,magToLookFor{i},'='));
	end

	%Find out how many datasets exist in the file
	fseek(fh,-1024,'eof');
	endPosition = ftell(fh);
	fseek(fh,-8,'cof');
	reverse = 8;
	while fread(fh,1,'uint64') ==0 && reverse <1024
		reverse = reverse +32;
		fseek(fh,-40,'cof');
	end
	%There's a header at the beginning and at the end
	fileLength = ftell(fh)-1024;	
	samples = fileLength/32;
	%Read data
	%Constants for the types of data in file
	recordType = {'uint8' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16'};
	recordLen = [1 2 2 2 2 2 2 2 2 2 13]; %uint8 (counter) uint16 x9 (acc x,y,z gyro x,y,z mag x,y,z)
	data.channels = cell(1,numel(recordType));
	% read the file column-by-column
	for i=1:numel(recordType)	%Note that the recordType is one cell shorter than the recordLen, the remaining 13 bits are for GPS data
		%Seek past the header 1024 + 2 bytes for the packet identifier 13 7F
		fseek(fh, 1026, 'bof');
		% seek to the first field of the first record
		fseek(fh, sum(recordLen(1:i-1)), 'cof');
		% read column with specified format, skipping required number of bytes
		data.channels{i} = double(fread(fh, samples, ['*' recordType{i}], sum(recordLen)-recordLen(i)));
		%scale GRF
		if i >= 2 && i<=4	
			accCVector = [data.accCalib((i-1)*2-1); data.accCalib((i-1)*2)]
			A = [repmat(1,2,1) accCVector];
			B = [1; -1];
			coefficient = A\B;
			data.channels{i} = data.channels{i}*coefficient(2)+coefficient(1);
		end
		%scale gyro
		if i >= 5 && i<=7	
			gyroCVector = [data.gyroCalib((i-4)*2-1); data.gyroCalib((i-4)*2)]
			data.channels{i} = (data.channels{i}-gyroCVector(1))*gyroCVector(2);	%16 bit, +-16g
		end
		%scale magnetometer
		if i >= 8 && i<=10	
			magCVector = [data.magCalib((i-7)*2-1); data.magCalib((i-7)*2)]
			A = [repmat(1,2,1) magCVector];
			B = [1; -1];
			coefficient = A\B;
			data.channels{i} = data.channels{i}*coefficient(2)+coefficient(1);
		end		
	end
	fclose(fh);
endfunction;