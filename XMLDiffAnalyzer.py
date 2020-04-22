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
            ["java -cp ", "diffxml", "diffxml.jar org.diffxml.diffxml.DiffXML ", " "]
        ]

    def start(self, rounds, file_pairs, files_orig, files_new, file_delta_dir):
        import os
        import csv
        import Processor
        from datetime import datetime

        ROOT_DIR = os.path.abspath(os.curdir)

        print("Starting...")

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

        times_list = []
        average_memories_list = []
        max_memories_list = []
        for file_pair in range(0, file_pairs):
            self.file_orig = files_orig[file_pair]
            self.file_new = files_new[file_pair]
            row_list = []
            index = 0
            algorithms = []
            times = []

            max_memories = []
            average_memories = []
            delta_sizes = []

            print(str(rounds) + " round iteration")
            for tool in self.tools:
                processor = Processor.Processor(ROOT_DIR, tool, rounds, file_pair, files_orig[file_pair],
                                                files_new[file_pair], file_delta_dir)
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
                                 format(os.stat(files_orig[file_pair]).st_size / 1024, '.2f'),
                                 format(os.stat(files_new[file_pair]).st_size / 1024, '.2f'),
                                 processor.file_delta_size,
                                 processor.total_time,
                                 os.path.basename(files_orig[file_pair]),
                                 os.path.basename(files_new[file_pair]),
                                 os.path.basename(processor.file_delta)
                                 ])

                print(tool[1] + " - file pair " + str(file_pair + 1))
                # print("\t" + myCmd)    #For debug
                print("\tAverage time:", str(processor.total_time) + " sec")
                print("\tMax RSS Memory:", str(processor.max_memory) + " MB")
                print("\tAverage memory:", str(processor.average_memory) + " MB")
                print("\tFile delta:")
                print("\t\tPath: " + processor.file_delta)
                print("\t\tSize: ", str(processor.file_delta_size) + " KB")
                print("")

            with open(csv_file, "a", newline="") as file:
                writer = csv.writer(file)
                writer.writerows(row_list)

            times_list.append(times)
            average_memories_list.append(average_memories)
            max_memories_list.append(max_memories)

            xmlDiffAnalyzer.generateGraph("Execution Time", "simple", "Seconds", 5, algorithms,
                                          {"Time": times})

            xmlDiffAnalyzer.generateGraph("Memory Usage", "double", "MB", 250, algorithms,
                                          {"MAX": max_memories,
                                          "AVG": average_memories})

            xmlDiffAnalyzer.generateGraph("Delta File Size", "simple", "KB", 360,
                                          algorithms, {"delta size": delta_sizes})


        #xmlDiffAnalyzer.generateGraph("Memory Usage", "quadruple", "MB", 250, algorithms,
        #                                  {"One text delete MAX": max_memories_list[0],
        #                                   "One text delete AVG": average_memories_list[0],
        #                               "Real-life author changes MAX": max_memories_list[1],
        #                               "Real-life author changes AVG": average_memories_list[1]
        #                               })

        #xmlDiffAnalyzer.generateGraph("Execution Time", "double", "Seconds", 5, algorithms,
        #                           {"One text delete": times_list[0], "Real-life author changes": times_list[1]})


    def generateGraph(self, name, type, units, xlim, algorithms, data):
        import matplotlib.pyplot as plt
        import pandas
        from datetime import datetime

        plt.rcdefaults()


        if type == "simple":
            df = pandas.DataFrame({list(data)[0]: data.get(list(data)[0])}, index=algorithms)
            y_variance = .15
            fontsize = 10
            df = df.sort_values(list(data)[0])
        elif type == "double":
            df = pandas.DataFrame({list(data)[0]: data.get(list(data)[0]),
                                   list(data)[1]: data.get(list(data)[1])}, index=algorithms)
            y_variance = .07
            fontsize = 9
            df = df.sort_values(list(data)[1])
        else:
            df = pandas.DataFrame({list(data)[0]: data.get(list(data)[0]),
                                   list(data)[1]: data.get(list(data)[1]),
                                   list(data)[2]: data.get(list(data)[2]),
                                   list(data)[3]: data.get(list(data)[3])}, index=algorithms)
            y_variance = .07
            fontsize = 9
            df = df.sort_values(list(data)[0])

        df = df.astype(float)
        ax = df.plot.barh()

        props = dict(boxstyle='round', facecolor='white', alpha=0.9)
        for i in ax.patches:
            if i.get_width() > xlim:
                ax.text(xlim - xlim / 6, i.get_y() + y_variance, str(int((i.get_width()))), fontsize=fontsize,
                        bbox=props, color='red')

        ax.set_xlabel(units)
        ax.set_title(name)
        ax.legend(loc="lower right")
        plt.grid(True)
        plt.xlim(0, xlim)
        plt.savefig("Results/XMLDiffAnalyser_results_" + str(os.path.basename(self.file_orig))
                    + "_" + str(os.path.basename(self.file_new))
                    + str(datetime.today().strftime('%Y%m%d_%H%M%S')) + "_" + name + ".svg")
        plt.show()


if __name__ == '__main__':
    import os
    xmlDiffAnalyzer = XMLDiffAnalyzer()

    while True:
        input_files_orig = []
        input_files_new = []
        input_rounds = 0

        try:
            while not int(input_rounds) in range(1, 100):
                input_rounds = int(input("Enter the number of rounds between 1 and 100 (default 1): ") or "1")
        except ValueError:
            print("Please provide a vaild number from 1 to 100")

        file_pairs = 0
        try:
            while not int(file_pairs) in range(1, 40):
                file_pairs = int(input("Enter the number of file pairs between 1 and 40 (default 1): ") or "1")
        except ValueError:
            print("Please provide a vaild number of file pairs from 1 to 40")

        for file_pair in range(1, file_pairs + 1):
            try:
                input_file_orig = input("Enter the full path of the original XML file pair " + str(file_pair) + ": ") \
                or "/Users/miloscuculovic/XML_Diff_tools_material_v2/OneChange/one_change_orig.xml"
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
                or "/Users/miloscuculovic/XML_Diff_tools_material_v2/OneChange/one_change_new.xml"
            except ValueError:
                print("Please provide a vaild modified XML file path")
            try:
                file_new = open(input_file_new)
            except IOError:
                print("Please provide a vaild modified XML file path - File not accessible")
            finally:
                file_new.close()

            if input_rounds < 1 or input_rounds > 100:
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

        xmlDiffAnalyzer.start(input_rounds, file_pairs, input_files_orig, input_files_new, input_file_delta_dir)