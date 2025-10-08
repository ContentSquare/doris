you cannot under any circomnstance laun a ./buid.sh command with the --clean option
## running tests for be 
you can run the test with for be
```sh
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.16/libexec/openjdk.jdk/Contents/Home;export JDK_17=$JAVA_HOME; ./run-be-ut.sh --run --filter="your filter goes here"
```
make sure you change the filter accordingly or remove the --filter option if you want to run all the tests 

 1. Rebuild: ./build.sh --be                                                                                                                                         
  2. Create Image: docker build -f                                                                                                                                    
  docker/runtime/doris-compose/Dockerfile -t my-doris:dev .                                                                                                           
  3. Deploy: docker-compose -f docker-compose-simple.yml up -d doris-be1                                                                                              
   doris-be2

while in local dev logs are in output/be/logs and output/fe/logs
