毎週日曜日に、西糀谷の来週のゴミ収集予定を教えてくれるツールです

■構築手順
1. line developer のchannelを作成する
    参考：https://qiita.com/nkjm/items/38808bbc97d6927837cd
2. messaging APIのにて、Channel access tokenを確認。控えておく
3. cd envs/dev
4. terraform apply
    var.line_token
      Enter a value: <channnel access token>

    Do you want to perform these actions?
      Terraform will perform the actions described above.
      Only 'yes' will be accepted to approve.

      Enter a value: 

        →構築完了