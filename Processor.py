import os
import ProcessTimer
import time

class Processor:
    def __init__(self,ROOT_DIR,tool,rounds,file_orig,file_new,file_delta_dir):
        self.tool = tool
        self.rounds = rounds
        self.file_orig = file_orig
        self.file_new = file_new
        self.file_delta_dir = file_delta_dir
        self.ROOT_DIR = ROOT_DIR

        self.total_time = 0
        self.max_memory = 0
        self.average_memory = 0
        self.file_delta_size = 0
        self.file_delta = ""

    def start(self):
        total_time = 0
        max_memory = 0
        average_memories = []

        myCmd = self.tool[0] + self.ROOT_DIR + "/XMLDiffTools/" + self.tool[2] + self.file_orig + self.tool[3] + self.file_new
        file_delta = self.file_delta_dir + self.tool[1] + "_delta.xml"

        first_round = True
        for round in range(0, self.rounds):
            if self.tool[4] != "":
                myCmd += self.tool[4] + file_delta
            elif first_round:
                myCmd += " >> " + file_delta
                first_round = False

            ptimer = ProcessTimer.ProcessTimer(myCmd)

            try:
                ptimer.execute()
                while ptimer.poll():
                    time.sleep(.0001)
            finally:
                ptimer.close()

            current_time = ptimer.t1 - ptimer.t0
            total_time += current_time
            max_memory = max(max_memory, ptimer.max_rss_memory)
            average_memories.append(sum(ptimer.rss_memory) / len(ptimer.rss_memory))

        self.total_time = format(total_time, '.2f')
        self.max_memory = format((max_memory) / (1024 * 1024), '.3f')
        self.average_memory = format((sum(average_memories) / len(average_memories)) / (1024 * 1024), '.3f')
        self.file_delta_size = format((os.stat(file_delta).st_size) / (1024), '.2f')
        self.file_delta = file_delta

        print(self.tool[1] + ":")
        # print("\t" + myCmd)    #For debug
        print("\tTotal time:", str(self.total_time) + " sec")
        print("\tMax RSS Memory:", str(self.max_memory) + " MB")
        print("\tAverage memory:", str(self.average_memory) + " MB")
        print("\tFile delta:")
        print("\t\tPath: " + self.file_delta)
        print("\t\tSize: ", str(self.file_delta_size) + " KB")
