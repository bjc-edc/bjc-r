1. First Time Use:

    You have to install Ruby if you do not already have it.
    https://www.ruby-lang.org/en/

    Next, you will need to install the 'rio' module. 
    Open your terminal to run and open ruby terminal
    >>> irb
    If you have windows, you can enter the following 
    in the ruby terminal 
    >>>(irb): gem install rio
    >>>(irb): gem install fileutils
    >>>(irb): gem install nokogiri
    >>>(irb): gem install twitter_cldr

2. To Run Tests:

    Go into the directory with the building tools
    and run the ruby program.
    >>> cd bjc-r/utilities/build-tools
    >>> irb -r ./tests.rb
    The above will open the ruby terminal. You will now need to pass in
    specific test functions. Look at the tests.rb file for specific tests.

    First initialize the testing object:
    >>> t = Tests.new()
    >>> t.[NameOfTestFunction]
    [NameOfTestFunction] being one of the functions as a parameter in the tests.rb file

    Example for running english CSP test:
    >>> t = Tests.new()
    >>> t.mainCSP()

    Example for running spanish CSP test:
    >>> t = Tests.new()
    >>> t.mainCSPSpanish()

3. To Run Actual Curriculum pages:

    Go into the directory with the building tools
    and run the ruby program.
    >>> cd bjc-r/utilities/build-tools
    The above will open the ruby terminal.
    Everything runs from main.rb using the main function and object

    First create the main object and then call the main function,
    which takes in the class curriculum folder, class topic folder 
    and specified language as string inputs.
    
    Note, that the folders are local to your drive (i.e. C:/Users/I560638)
    >>> myMain = Main.new([classFolder], [topicsFolder], [language])
    >>> myMain.main()

    Example for running english CSP:
    >>> engCSP = Main.new("C:/Users/I560638/bjc-r/cur/programming", "C:/Users/I560638/bjc-r/topic/nyc_bjc", "en")
    >>> engCSP.main()

     Example for running spanish CSP:
    >>> esCSP = Main.new("C:/Users/I560638/bjc-r/cur/programming", "C:/Users/I560638/bjc-r/topic/nyc_bjc", "es")
    >>> esCSP.main()


4. General:

    To open a specific ruby file, enter the following with the [file]
    being a specified file name (parameter).
    >>> irb ./[file].rb
    To open a specific ruby file in interative mode. 
    **There may be an issue with one of the ruby gems if you run this line in gitbash.
    >>>irb -r ./[file].rb


5. Running Locally:

    Once the summary pages have generated go to parent directory of bjc-r
    then load the localhost
    >>>python -m http.server