class XMLDiffAnalyzer:
    def __init__(self):
        self.tools = [
            ["", "xydiff", "xydiff ", " "],
            ["java -jar ", "jndiff", "jndiff/jndiff-ui.jar -d ", " "],
            ["java -jar ", "jxydiff", "jxydiff.jar ", " ", " "],
            ["ant -buildfile ", "fc-xmldiff", "fc-xmldiff/java/xmldiff/build.xml -Dbase=", " -Dnew=", " -Ddiff=", " diff"],
            ["java -jar ", "xcc", "xcc-java-0.90.jar --diff --doc ", " --changed ", " --delta "],
            ["", "node-delta", "node-delta/bin/djdiff.js -p xml ", " "],
            ["java -jar ", "deltaXML", "deltaXML/command-10.3.0.jar compare delta ", " ", " "], #License needed
            ["", "xmldiff", "xmldiff_bin -f xml ", " "], #Has issues with "UnicodeEncodeError: 'ascii' codec can't encode character u'\xe0' in position xxxx"
            ["java -jar ", "xop", "xop.jar -script on ", " - ", ""],
            ["java -cp ", "diffmk", "diffmk.jar net.sf.diffmk.DiffMk ", " ", " "],
            ["", "xdiff", "xdiff ", " ", " "],
            ["", "xdiff-go", "XDiff-go -left ", " -right ", ""],
            ["java -cp ", "diffxml", "diffxml.jar org.diffxml.diffxml.DiffXML ", " "]
        ]

    def start(self, mode, rounds, file_pairs, files_orig, files_new, file_delta_dir):
        import os
        import csv
        import Processor
        from datetime import datetime

        ROOT_DIR = os.path.abspath(os.curdir)

        print("Starting...")

        excel_headers = [
            [0, 'A1', 'Tool'],
            [1, 'B1', 'Rounds'],
            [2, 'C1', 'Average memory (MB)'],
            [3, 'D1', 'Max memory (MB)'],
            [4, 'E1', 'File orig size (KB)'],
            [5, 'F1', 'File modified size (KB)'],
            [6, 'G1', 'File delta size (KB)'],
            [7, 'H1', 'Time (sec)'],
            [8, 'I1', 'File orig'],
            [9, 'J1', 'File modified'],
            [10, 'K1', 'File delta'],
        ]

        csv_file = ROOT_DIR + "/Results/XMLDiffAnalyser_results_" + str(datetime.today().strftime('%Y%m%d_%H%M%S')) + ".csv"

        with open(csv_file, "w", newline="") as file:
            writer = csv.writer(file)
            writer.writerow(["Tool",
                     "Rounds",
                     "Average memory (MB)",
                     "Max memory (MB)",
                     "File orig size (KB)",
                     "File modified size (KB)",
                     "File delta size (KB)",
                     "Time (sec)",
                     "File orig",
                     "File modified",
                     "File delta"])
        row_list = []

        index = 0
        algorithms = []
        times = []
        max_memories = []
        average_memories = []
        delta_sizes = []

        if mode == "A":
            rounds_list = [1, 10, 100]
        else:
            rounds_list = [rounds]

        for file_pair in range(0, file_pairs):
            for rounds in rounds_list:
                print(str(rounds) + " round iteration")
                for tool in self.tools:
                    processor = Processor.Processor(ROOT_DIR, tool, rounds, file_pair, files_orig[file_pair], files_new[file_pair], file_delta_dir)
                    processor.start()
                    index += 1
                    algorithms.append(str(tool[1]))
                    times.append(processor.total_time)
                    max_memories.append(processor.max_memory)
                    average_memories.append(processor.average_memory)
                    delta_sizes.append(processor.file_delta_size)
                    row_list.append([str(tool[1]),
                                     rounds,
                                     processor.average_memory,
                                     processor.max_memory,
                                     format((os.stat(files_orig[file_pair]).st_size) / (1024), '.2f'),
                                     format((os.stat(files_new[file_pair]).st_size) / (1024), '.2f'),
                                     processor.file_delta_size,
                                     processor.total_time,
                                     os.path.basename(files_orig[file_pair]),
                                     os.path.basename(files_new[file_pair]),
                                     os.path.basename(processor.file_delta)
                                     ])

                    print(tool[1] + " - file pair " + str(file_pair + 1))
                    # print("\t" + myCmd)    #For debug
                    print("\tTotal time:", str(processor.total_time) + " sec")
                    print("\tMax RSS Memory:", str(processor.max_memory) + " MB")
                    print("\tAverage memory:", str(processor.average_memory) + " MB")
                    print("\tFile delta:")
                    print("\t\tPath: " + processor.file_delta)
                    print("\t\tSize: ", str(processor.file_delta_size) + " KB")
                    print("")

        with open(csv_file, "a", newline="") as file:
            writer = csv.writer(file)
            writer.writerows(row_list)

        xmlDiffAnalyzer.generateGraph("Execution Time", "simple", "Seconds", 6, algorithms, {"time": times})
        xmlDiffAnalyzer.generateGraph("Memory Usage", "double", "MB", 230, algorithms,
                      {"max memory": max_memories, "average memory": average_memories})
        xmlDiffAnalyzer.generateGraph("Delta File Size", "simple", "KB", 500, algorithms, {"delta size": delta_sizes})


    def generateGraph(self, name, type, units, xlim, index, data):
        import matplotlib.pyplot as plt
        import pandas
        from datetime import datetime

        plt.rcdefaults()

        if(type == "simple"):
            df = pandas.DataFrame({list(data)[0]: data.get(list(data)[0])}, index=index)
        else:
            df = pandas.DataFrame({list(data)[0]: data.get(list(data)[0]),
                                   list(data)[1]: data.get(list(data)[1])}, index=index)

        df = df.astype(float)
        ax = df.plot.barh()
        ax.set_xlabel(units)
        ax.set_title(name)
        plt.grid(True)
        plt.xlim(0, xlim)
        plt.savefig("Results/XMLDiffAnalyser_results_" + str(
            datetime.today().strftime('%Y%m%d_%H%M%S')) + "_" + name + ".svg")
        plt.show()


if __name__ == '__main__':
    import os
    xmlDiffAnalyzer = XMLDiffAnalyzer()

    while True:
        mode = "X"
        input_files_orig = []
        input_files_new = []

        while not str(mode) in ("A", "M"):
            mode = input("Mode: M for Manual (default), A for Auto (1, 10, 100 rounds): ") or "M"

        input_rounds = 0
        if mode == "M":
            try:
                while not int(input_rounds) in range(1, 1000):
                    input_rounds = int(input("Enter the number of rounds between 1 and 1000 (default 1): ") or "1")
            except ValueError:
                print("Please provide a vaild number from 1 to 1000")

        file_pairs = 0
        try:
            while not int(file_pairs) in range(1, 40):
                file_pairs = int(input("Enter the number of file pairs between 1 and 40 (default 1): ") or "1")
        except ValueError:
            print("Please provide a vaild number of file pairs from 1 to 40")

        for file_pair in range(1, file_pairs + 1):
            try:
                input_file_orig = input("Enter the full path of the original XML file pair " + str(file_pair) +": ") \
                or "/Users/miloscuculovic/XML_Diff_tools_material_v1/1.xml"
            except ValueError:
                print("Please provide a vaild original XML file path")

            try:
                file_orig = open(input_file_orig)
            except IOError:
                print("Please provide a vaild original XML file path - File not accessible")
            finally:
                file_orig.close()

            try:
                input_file_new = input("Enter the full path of the modified XML file pair " + str(file_pair) + ": ") \
                or "/Users/miloscuculovic/XML_Diff_tools_material_v1/2.xml"
            except ValueError:
                print("Please provide a vaild modified XML file path")
            try:
                file_new = open(input_file_new)
            except IOError:
                print("Please provide a vaild modified XML file path - File not accessible")
            finally:
                file_new.close()

            if mode == "M" and (input_rounds < 1 or input_rounds > 1000):
                print("Please provide a vaild number from 1 to 1000")
                continue

            input_files_orig.append(input_file_orig)
            input_files_new.append(input_file_new)

        try:
            input_file_delta_dir = input("Enter the full path of the delta XML files directory: ") \
                                   or "/Users/miloscuculovic/deltas/"
        except ValueError:
            print("Please provide a vaild delta XML files directory file path")

        try:
            os.path.isdir(input_file_delta_dir)
        except IOError:
            print("Please provide a vaild modified XML file path - Directory not accessible")
        finally:
            file_new.close()

        xmlDiffAnalyzer.start(mode, input_rounds, file_pairs, input_files_orig, input_files_new, input_file_delta_dir)