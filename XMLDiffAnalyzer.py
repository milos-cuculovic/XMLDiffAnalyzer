class XMLDiffAnalyzer:
    def __init__(self):
        self.file_orig = "/Users/miloscuculovic/Desktop/XML_Diff_tools_material/Originals/article_min.xml"
        self.file_new = "/Users/miloscuculovic/Desktop/XML_Diff_tools_material/TextEdits/text_edit_delete/article_min_text_edit_delete.xml"
        self.file_delta = "/Users/miloscuculovic/Desktop/XML_Diff_tools_material/delta"

        self.tools_path = "/Users/miloscuculovic/git/XMLDifftools/"
        self.tools = [
            ["", "xydiff", "xydiff ", " ", ""],
            ["java -jar ", "jndiff-1.2", "jndiff-ui.jar -d ", " ", ""],
            ["", "diffxml", "diffxml.sh ", " ", ""],
            ["java -jar ", "xcc", "xcc-java-0.90.jar --diff --doc ", " --changed ", " --delta "],
            ["", "node-delta", "bin/djdiff.js -p xml ", " ", ""],
            ["java -jar ", "DeltaXML-XML-Compare-10_1_2_j", "command-10.1.2.jar compare delta ", " ", " "],
            ["", "xmldiff", "xmldiff_bin -f xml ", " ", ""], #Has issues with "UnicodeEncodeError: 'ascii' codec can't encode character u'\xe0' in position xxxx"
            ["", "xdiff", "xdiff -left ", " -right ", ""],
            ["java -jar ", "xop-1", "xop.jar -script on ", " - ", ""],
            ["", "diffmk", "run.sh ", " ", " "]
        ]

    def start(self, rounds = 1):
        import os
        import subprocess
        import psutil
        from datetime import datetime

        print("Starting...")

        for row in self.tools:
            print(row[1])
            start_time = datetime.now()
            total_memory = 0
            for round in range(0, rounds):
                myCmd = row[0] + self.tools_path + row[1] + "/" + row[2] + self.file_orig + row[3] + self.file_new
                if row[4] != "":
                    myCmd += row[4] + self.file_delta + "_" + row[1] + ".xml 2>&1"
                else:
                    myCmd += " >> " + self.file_delta + "_" + row[1] + ".xml 2>&1"
                #pid = os.system(myCmd)

                process = subprocess.Popen(myCmd, shell=True)
                process_psutil = psutil.Process(process.pid)
                total_memory += process_psutil.memory_info().rss

            end_time = datetime.now()
            total_time = end_time - start_time
            print("Total time for " + row[1] + " = ", total_time)
            print(str(total_memory / 1024) + "MB")  # in bytes


if __name__ == '__main__':

    xmlDiffAnalyzer = XMLDiffAnalyzer()
    print("Test for diff tools")
    while True:
        try:
            input_value = input("Enter the number of rounds: ")
            rounds = int(input_value)
        except ValueError:
            print("Please provide a vaild number from 1 to 10 000")
        try:
            input_value = input("Enter the full path of the original XML file: ")
            file_orig = int(input_value)
        except ValueError:
            print("Please provide a vaild number from 1 to 10 000")
        try:
            input_value = input("Enter the full path of the modified XML file: ")
            file_new = int(input_value)
        except ValueError:
            print("Please provide a vaild number from 1 to 10 000")
        try:
            input_value = input("Enter the full path of the resulting delta file without the file extension: ")
            file_delta = int(input_value)
        except ValueError:
            print("Please provide a vaild number from 1 to 10 000")

        if rounds < 1 or rounds > 10000:
            print("Please provide a vaild number from 1 to 10 000")
            continue
        xmlDiffAnalyzer.start(rounds)