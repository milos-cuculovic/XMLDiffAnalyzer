class XMLDiffAnalyzer:
    def __init__(self):
        self.tools = [
            ["", "xydiff", "xydiff ", " ", ""],
            ["java -jar ", "jndiff", "jndiff/jndiff-ui.jar -d ", " ", ""],
            ["java -cp ", "diffxml", "diffxml.jar org.diffxml.diffxml.DiffXML ", " ", ""],
            ["java -jar ", "xcc", "xcc-java-0.90.jar --diff --doc ", " --changed ", " --delta "],
            ["", "node-delta", "node-delta/bin/djdiff.js -p xml ", " ", ""],
            ["java -jar ", "deltaXML", "deltaXML/command-10.1.2.jar compare delta ", " ", " "],
            ["", "xmldiff", "xmldiff_bin -f xml ", " ", ""], #Has issues with "UnicodeEncodeError: 'ascii' codec can't encode character u'\xe0' in position xxxx"
            ["", "xdiff", "xdiff -left ", " -right ", ""],
            ["java -jar ", "xop", "xop.jar -script on ", " - ", ""],
            ["java -cp ", "diffmk", "diffmk.jar net.sf.diffmk.DiffMk ", " ", " "]
        ]

    def start(self, rounds, file_orig, file_new, file_delta_dir):
        import os
        import subprocess
        import psutil
        from datetime import datetime
        import ProcessTimer
        import time
        from datetime import timedelta
        ROOT_DIR = os.path.abspath(os.curdir)

        print("Starting...")

        for row in self.tools:
            total_time = 0
            max_memory = 0
            average_memory = 0

            for round in range(0, rounds):
                myCmd = row[0] + ROOT_DIR+"/XMLDiffTools/" + row[2] + file_orig + row[3] + file_new
                if row[4] != "":
                    myCmd += row[4] + file_delta_dir + row[1] + ".xml"
                else:
                    myCmd += " >> " + file_delta_dir + row[1] + "_delta.xml"

                ptimer = ProcessTimer.ProcessTimer(myCmd)

                try:
                    ptimer.execute()
                    # poll as often as possible; otherwise the subprocess might
                    # "sneak" in some extra memory usage while you aren't looking
                    while ptimer.poll():
                        time.sleep(.0001)
                finally:
                    # make sure that we don't leave the process dangling?
                    ptimer.close()

                current_timpe = ptimer.t1 - ptimer.t0
                total_time += current_timpe
                max_memory = max(max_memory, ptimer.max_rss_memory)
                average_memory = sum(ptimer.rss_memory) / len(ptimer.rss_memory)

            print(row[1] + ":")
            print("\tTotal time:", format(total_time,'.2f') + " sec")
            print("\tMax RSS Memory:", str(format((max_memory) / (1024 * 1024), '.3f')) + " MB")
            print("\tAverage memory:", str(format((average_memory) / (1024 * 1024), '.3f')) + " MB")

if __name__ == '__main__':
    import os
    xmlDiffAnalyzer = XMLDiffAnalyzer()
    print("Test for diff tools")
    while True:
        try:
            input_rounds = int(input("Enter the number of rounds (default 1): ") or "1")
        except ValueError:
            print("Please provide a vaild number from 1 to 10 000")

        try:
            input_file_orig = input("Enter the full path of the original XML file: ") \
                              or "/Users/miloscuculovic/XML_Diff_tools_material/Originals/article_min.xml"
        except ValueError:
            print("Please provide a vaild original XML file path")
        try:
            file_orig = open(input_file_orig)
        except IOError:
            print("Please provide a vaild original XML file path - File not accessible")
        finally:
            file_orig.close()

        try:
            input_file_new = input("Enter the full path of the modified XML file: ") \
                             or "/Users/miloscuculovic/XML_Diff_tools_material/TextEdits/text_edit_delete/article_min_text_edit_delete.xml"
        except ValueError:
            print("Please provide a vaild modified XML file path")
        try:
            file_new = open(input_file_new)
        except IOError:
            print("Please provide a vaild modified XML file path - File not accessible")
        finally:
            file_new.close()

        try:
            input_file_delta_dir = input("Enter the full path of the delta XML files directory: ") \
                                   or "/Users/miloscuculovic/XML_Diff_tools_material/"
        except ValueError:
            print("Please provide a vaild delta XML files directory file path")
        try:
            os.path.isdir(input_file_delta_dir)
        except IOError:
            print("Please provide a vaild modified XML file path - Directory not accessible")
        finally:
            file_new.close()

        if input_rounds < 1 or input_rounds > 10000:
            print("Please provide a vaild number from 1 to 10 000")
            continue
        xmlDiffAnalyzer.start(input_rounds, input_file_orig, input_file_new, input_file_delta_dir)