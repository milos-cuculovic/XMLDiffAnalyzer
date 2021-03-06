import os
import ProcessTimer
import time
from termcolor import colored
import os.path
from os import path

class Processor:
    def __init__(self,ROOT_DIR,tool,rounds,file_pair,file_orig,file_new,file_delta_dir):
        self.tool = tool
        self.rounds = rounds
        self.file_pair = file_pair
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

        file_delta = self.file_delta_dir + self.tool[1] + "_" + str(os.path.basename(self.file_orig)) + "_" + str(os.path.basename(self.file_new)) + "_delta.xml"

        first_round = True
        for round in range(0, self.rounds):
            if len(self.tool) > 4:
                if self.tool[4] != "":
                    myCmd += self.tool[4] + file_delta
                elif first_round:
                    myCmd += " > " + file_delta
                    first_round = False
            elif first_round:
                myCmd += " > " + file_delta
                first_round = False

            if len(self.tool) > 5:
                if self.tool[5] != "":
                    myCmd += self.tool[5]

            print(myCmd)
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

        self.total_time = float(format(total_time / int(self.rounds), '.1f'))
        self.max_memory = float(format(max_memory / (1024 * 1024), '.1f'))
        self.average_memory = format((sum(average_memories) / len(average_memories)) / (1024 * 1024), '.1f')
        self.file_delta = file_delta
        if path.exists(file_delta):
            self.file_delta_size = float(format(os.stat(file_delta).st_size / 1024, '.1f'))
        else:
            self.file_delta_size = 0
            print(colored("!!ATTENTION!! Delta file not created! !!ATTENTION!! ", "red"))
