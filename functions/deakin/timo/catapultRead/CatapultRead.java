package deakin.timo.catapultRead;
import java.util.ArrayList;
public class CatapultRead{
/*
	private short[][] codes = {	{0xA5,0x10},
								{0xA6,0x10},
								{0x6D,0xBC},
								{0x7F,0x13}
								};
								*/
	private int[] packetLengths = {	20,
									20,
									190,
									21
									};
	private ArrayList<Double> counters;
	private ArrayList<Double>[] data;
	public CatapultRead(double[] dataIn){
		counters	= new ArrayList<Double>();
		data		= (ArrayList<Double>[]) new ArrayList[9];
		for (int i = 0; i<data.length;++i){
			data[i] = new ArrayList<Double>();
		}
		/*Go through the data*/
		int i = 0;
		int ignore = 0;

		while (i < dataIn.length-1){
			int cond = ((int)dataIn[i])<<8 | ((int) dataIn[i+1]);
			//System.out.println("Cond "+cond+" data field "+0x7F13);
			switch (cond){
				case 0xA510:	//Session info
					i+=packetLengths[0];
					break;
				case 0xA610:	//Session info2
					i+=packetLengths[1];
					break;
				case 0x6DBC:	//GPS
					i+=packetLengths[2];
					break;
				case 0x7F13:	//IMU packet
					if (ignore < 50){
						++ignore;
					}else{
						counters.add(dataIn[i+2]);	//Get counter value
						for (int d = 0;d<data.length;++d){
							//data[d].add((double) (((int)dataIn[i+3+(2*d)])<<8 | ((int) dataIn[i+3+(2*d+1)])));
							data[d].add((double) (((int)dataIn[i+3+(2*d)]) | ((int) dataIn[i+3+(2*d+1)])<<8));
						}
					}
					i+=packetLengths[3];
					break;
				default:
					++i;
					break;
			}
		}
	}
	
	public double[][] getData(){
		double[][] returnData = new double[data.length][data[0].size()];
		//System.out.println("ReturnSize "+returnData.length+" "+returnData[0].length);
		for (int i = 0; i<data.length;++i){
			//System.out.println("dataLength "+data[i].size());
			for (int j = 0; j<data[i].size();++j){
				returnData[i][j] = data[i].get(j);
			}
		}
		return returnData;
	}
	public double[] getCounters(){
		double[] count = new double[counters.size()];
		//System.out.println("Counter size "+count.length);
		for (int i = 0; i<counters.size();++i){
			count[i] = counters.get(i);
		}
		return count;
	}
}