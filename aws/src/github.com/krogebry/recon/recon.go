package main

import (
  "io"
  "os"
  "log"
  "compress/gzip"

  //"github.com/aws/aws-sdk-go/aws"
  //"github.com/aws/aws-sdk-go/aws/session"
  //"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

func main() {

  svc := s3.New(session.New(&aws.Config{Region: aws.String("us-west-2")}))
  result, err := svc.ListBuckets(&s3.ListBucketsInput{})
  if err != nil {
    log.Println("Failed to list buckets", err)
    return
  }

  log.Println("Buckets:")

  for _, bucket := range result.Buckets {
    log.Printf("%s : %s\n", aws.StringValue(bucket.Name), bucket.CreationDate)
  }

  file, err := os.Create("download_file")
  if err != nil {
    log.Fatal("Failed to create file", err)
  }
  defer file.Close()

  downloader := s3manager.NewDownloader(session.New(&aws.Config{Region: aws.String("us-west-2")}))
  numBytes, err := downloader.Download(file,
    &s3.GetObjectInput{
        Bucket: aws.String("myBucket"),
        Key:    aws.String("myKey"),
    })
  if err != nil {
    fmt.Println("Failed to download file", err)
    return
  }

  fmt.Println("Downloaded file", file.Name(), numBytes, "bytes")

}
