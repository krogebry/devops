package main

import (
  "os"
	"fmt"
  "bytes"
  "reflect"
  "io/ioutil"
	//"path/filepath"
  "compress/gzip"

  "crypto/sha1"

  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/aws/session"
  "github.com/aws/aws-sdk-go/service/s3"
  "github.com/aws/aws-sdk-go/service/s3/s3manager"

  "database/sql"
  _ "github.com/go-sql-driver/mysql"

  //"github.com/aws/aws-sdk-go/service/dynamodb"
  //log "github.com/Sirupsen/logrus"
)

var (
    Bucket = "ct-nmg-main"
    Prefix = "AWSLogs/168860074409/CloudTrail/"
    LocalDirectory = "s3logs"
)

func main() {

  sess, err := session.NewSession()
  if err != nil {
    fmt.Println("failed to create session,", err)
    return
  }

  s3_client := s3.New( sess )

	params := &s3.ListObjectsInput{Bucket: aws.String("ct-nmg-main"), Prefix: aws.String("AWSLogs/168860074409/CloudTrail/")}
	manager := s3manager.NewDownloader( sess )

  dsn := fmt.Sprintf("%s:%s@tcp(%s:3306)/%s", 
            os.Getenv("DB_USER"),
            os.Getenv("DB_PASS"),
            os.Getenv("DB_HOST"),
            os.Getenv("DB_NAME"),)

  db, err := sql.Open("mysql", dsn)
  if err != nil {
    panic(err.Error()) // Just for example purpose. You should use proper error handling instead of panic
  }
  defer db.Close()

  stmtOut, err := db.Prepare("SELECT squareNumber FROM squarenum WHERE number = ?")
  if err != nil {
    panic(err.Error()) // proper error handling instead of panic in your app
  }
  defer stmtOut.Close()
  //fmt.Printf("Type: %s" + reflect.TypeOf(stmtOut))
  fmt.Println(reflect.TypeOf(stmtOut))

  //d := downloader{bucket: Bucket, Downloader: manager, mysqlStmt: stmtOut}
  d := downloader{bucket: Bucket, Downloader: manager}
  s3_client.ListObjectsPages(params, d.eachPage)
}

type downloader struct {
	*s3manager.Downloader
  //*mysql.mysqlStmt
  bucket, dir string
}

func (d *downloader) eachPage(page *s3.ListObjectsOutput, more bool) bool {
	for _, obj := range page.Contents {
		fmt.Println( obj )
		d.downloadToFile(*obj.Key)
  }
	return true
}

func (d *downloader) downloadToFile(key string) {
  fmt.Printf("Downloading " + key +"\n")

  h := sha1.New()
  h.Write([]byte( key ))
  bs := h.Sum(nil)
  checksum := fmt.Sprintf("%x", bs)
  fmt.Printf("Checksum: %s" + string(checksum))

  /**
  err = d.stmtOut.QueryRow(13).Scan(&squareNum) // WHERE number = 13
  if err != nil {
    panic(err.Error()) // proper error handling instead of panic in your app
  }
  fmt.Printf("The square number of 13 is: %d", squareNum)
  */

  buf := aws.NewWriteAtBuffer( []byte("") )
  params := &s3.GetObjectInput{Bucket: &d.bucket, Key: &key}
  d.Download(buf, params)

  r := bytes.NewReader( buf.Bytes() )

  gzip_reader, err := gzip.NewReader( r )
  if err != nil {
    panic( err )
  }

  fileContents, err := ioutil.ReadAll(gzip_reader)
  if err != nil {
    fmt.Println("[ERROR] ReadAll:", err)
  }
  fmt.Printf("[INFO] Uncompressed contents: %s\n", fileContents)

  os.Exit( 1 )
}

