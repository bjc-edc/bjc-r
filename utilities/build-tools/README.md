First you have to install Ruby if you do not already have it.
https://www.ruby-lang.org/en/

One you have entered ruby, you can go into the directory with the building tools
and run the ruby program
>>> cd bjc-r/sparks/student-pages/summaries
to run and open ruby terminal
>>> irb
to open a specific ruby file - to run the main ruby program you would run main.rb
>>> irb file.rb
to open a specific ruby file in interative mode. There may be an issue with one of the ruby gems if you run this line in gitbash.
>>>irb -r ./tests.rb

Next, you will need to install the 'rio' module.
If you have windows, you can enter the following 
in the ruby terminal 
>>>(irb): gem install rio
>>>(irb): gem install fileutils
>>>(irb): gem install nokogiri

Everything runs from main.rb using the main function
To call the main function, first create a main class instance
by doing the following in the irb terminal: 
>>> myMain = Main.new(classFolder, topicsFolder)
the classFolder and topicsFolder inputs should be the paths as strings
you can also run one of the tests by:
>>> t = Tests.new()
>>> t.NameOfTestFunction
NameOfTestFunction being one of the functions in the tests.rb file

Example for running english CSP test:
>>> t = Tests.new()
>>> t.mainCSP()

Example for running spanish CSP test:
>>> t = Tests.new()
>>> t.mainCSPSpanish()

Example for running the actual english CSP curriculum:
>>>

Once the summary pages have generated go to parent directory of bjc-r
then load the localhost
>>>python -m http.server
S